import logging
import requests
from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated, AllowAny

from authentication.permissions import IsAdmin, IsDelivery
from authentication.firebase import send_push_to_role
from orders.models import Order
from payments.models import (
    Payment,
    PaymentStatus,
    PaymentMethod,
)
from orders.serializers import (
    SelectPaymentSerializer,
    AdminPaymentMethodSerializer,
    OrderSerializer,
)
from config.logging import bind_log_context
from services.order_service import send_pending_online_payment_reminder
from .websocket import _broadcast_order

logger = logging.getLogger(__name__)


def _get_or_create_payment(order: Order, method: str, amount) -> Payment:
    """Return the Payment linked to this order, creating one if absent."""
    if order.payment_record_id:
        payment = order.payment_record
        payment.method = method
        payment.amount = amount
        payment.save(update_fields=["method", "amount", "updated_at"])
        return payment

    payment = Payment.objects.create(
        order=order,
        method=method,
        status=PaymentStatus.PENDING,
        amount=amount,
    )
    order.payment_record = payment
    order.save(update_fields=["payment_record"])
    return payment


from services.payments import initiate_cashfree_refund


class SelectPaymentView(APIView):
    """Customer selects payment method after the order is confirmed.

    cod    -> mark method, order proceeds straight to tracking.
    online -> create a Cashfree order and return the checkout params.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND
            )

        bind_log_context(
            order_id=order.id,
            customer=order.user_id,
            payment=order.payment_record_id,
            delivery_partner=order.assigned_delivery_id,
            status=order.status,
        )

        if order.status not in ["confirmed", "preparing", "out_for_delivery"]:
            return Response(
                {
                    "detail": "Order must be confirmed, preparing, or out for delivery "
                    "before payment."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        if order.payment_status == "paid":
            return Response(
                {"detail": "Order already paid."}, status=status.HTTP_400_BAD_REQUEST
            )

        serializer = SelectPaymentSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        method = serializer.validated_data["payment_method"]

        from services.payments import select_payment_method

        try:
            result = select_payment_method(order, method, request.user)
        except ValueError as e:
            return Response(
                {"detail": str(e)},
                status=(
                    status.HTTP_400_BAD_REQUEST
                    if method == "cod"
                    else status.HTTP_503_SERVICE_UNAVAILABLE
                ),
            )
        except ConnectionError as e:
            return Response(
                {"detail": str(e)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        payment = result.pop("payment", None)
        if payment:
            bind_log_context(payment=payment.id)

        if method == "cod":
            return Response(
                {"payment_method": "cod", "order": OrderSerializer(order).data}
            )

        return Response(
            {
                "payment_method": "online",
                "payment_session_id": result["payment_session_id"],
                "cf_order_id": result["cf_order_id"],
                "environment": result["environment"],
                "order": OrderSerializer(order).data,
            }
        )


class VerifyPaymentView(APIView):
    """Confirm payment with Cashfree and mark the order paid.

    Cashfree does not hand the client a signature to verify. Instead we
    fetch the order's status from Cashfree (server-to-server) and trust
    only ``order_status == "PAID"``.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND
            )

        bind_log_context(
            order_id=order.id,
            customer=order.user_id,
            payment=order.payment_record_id,
            delivery_partner=order.assigned_delivery_id,
            status=order.status,
        )

        # No online attempt has been started for this order yet.
        if not order.cashfree_order_id:
            return Response(
                {
                    "payment_status": order.payment_status,
                    "order": OrderSerializer(order).data,
                }
            )

        from services.payments import verify_payment

        try:
            result = verify_payment(order)
        except ValueError as e:
            return Response(
                {"detail": str(e)},
                status=status.HTTP_502_BAD_GATEWAY,
            )
        except ConnectionError as e:
            return Response(
                {"detail": str(e)},
                status=status.HTTP_502_BAD_GATEWAY,
            )

        return Response(
            {
                "payment_status": order.payment_status,
                "order_status": result.get("order_status", ""),
                "order": OrderSerializer(order).data,
            }
        )


class DriverInitiatePaymentView(APIView):
    """Driver requests/generates a native UPI Intent QR for COD to Online conversion."""

    permission_classes = [IsAdmin | IsDelivery]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND
            )

        bind_log_context(
            order_id=order.id,
            customer=order.user_id,
            payment=order.payment_record_id,
            delivery_partner=order.assigned_delivery_id,
            status=order.status,
        )

        from services.payments import driver_initiate_payment

        res = driver_initiate_payment(order)
        payment = res.pop("payment", None)
        if payment:
            bind_log_context(payment=payment.id)

        return Response(res)


class DriverVerifyPaymentView(APIView):
    """Driver marks payment as completed directly (bypassing UTR validation)."""

    permission_classes = [IsAdmin | IsDelivery]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND
            )

        bind_log_context(
            order_id=order.id,
            customer=order.user_id,
            payment=order.payment_record_id,
            delivery_partner=order.assigned_delivery_id,
            status=order.status,
        )

        from services.payments import driver_verify_payment

        res = driver_verify_payment(order)
        payment = res.pop("payment", None)
        if payment:
            bind_log_context(payment=payment.id)

        res["order"] = OrderSerializer(order).data
        return Response(res)


@method_decorator(csrf_exempt, name="dispatch")
class CashfreeWebhookView(APIView):
    """
    Cashfree webhook handler.

    Sandbox version:
    - Signature verification disabled
    - Handles PAYMENT_SUCCESS_WEBHOOK
    - Handles PAYMENT_FAILED_WEBHOOK
    """

    permission_classes = [AllowAny]

    def post(self, request):
        try:
            import json

            data = request.data

            logger.info("Webhook payload:\n%s", json.dumps(data, indent=2))

            event_type = data.get("type", "")
            event_data = data.get("data", {})

            logger.info(f"Webhook received: type={event_type}")

            # -------------------------
            # PAYMENT SUCCESS
            # -------------------------
            if event_type == "PAYMENT_SUCCESS_WEBHOOK":

                order_id_str = event_data.get("order", {}).get("order_id", "")

                cf_payment_id = event_data.get("payment", {}).get("cf_payment_id", "")

                if not order_id_str:
                    logger.warning("PAYMENT_SUCCESS_WEBHOOK received without order_id")
                    return Response({"status": "success"}, status=status.HTTP_200_OK)

                try:
                    order_number = "_".join(order_id_str.split("_")[:-1])

                    order = Order.objects.get(order_number=order_number)

                    bind_log_context(
                        order_id=order.id,
                        customer=order.user_id,
                        payment=order.payment_record_id,
                        delivery_partner=order.assigned_delivery_id,
                        status=order.status,
                    )

                    order.payment_status = "paid"
                    order.payment_id = str(cf_payment_id)

                    order.save(
                        update_fields=["payment_status", "payment_id", "updated_at"]
                    )

                    send_push_to_role(
                        "admin",
                        "Payment Received 💰",
                        f"Order #{order.order_number} has been paid online.",
                        {"order_id": str(order.id)},
                    )

                    logger.info(
                        f"Order marked PAID via webhook: " f"{order.order_number}"
                    )

                except Order.DoesNotExist:
                    logger.warning(f"Order not found: {order_id_str}")

            # -------------------------
            # PAYMENT FAILED
            # -------------------------
            elif event_type == "PAYMENT_FAILED_WEBHOOK":

                order_id_str = event_data.get("order", {}).get("order_id", "")

                logger.warning(f"Payment failed for order: {order_id_str}")

                try:
                    order_number = "_".join(order_id_str.split("_")[:-1])

                    order = Order.objects.get(order_number=order_number)

                    bind_log_context(
                        order_id=order.id,
                        customer=order.user_id,
                        payment=order.payment_record_id,
                        delivery_partner=order.assigned_delivery_id,
                        status=order.status,
                    )

                    order.payment_status = "failed"

                    order.save(update_fields=["payment_status", "updated_at"])

                except Order.DoesNotExist:
                    logger.warning(f"Order not found: {order_id_str}")

            else:
                logger.info(f"Ignoring webhook type: {event_type}")

            return Response({"status": "success"}, status=status.HTTP_200_OK)

        except Exception as e:
            logger.exception(f"Webhook processing failed: {str(e)}")

            return Response(
                {"status": "error", "message": str(e)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )


class AdminPaymentMethodView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND
            )

        if not (hasattr(request.user, "role") and request.user.role == "admin"):
            return Response(
                {"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN
            )

        serializer = AdminPaymentMethodSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        action = serializer.validated_data.get("action", "change_method")

        if order.status in ("delivered", "cancelled", "rejected"):
            return Response(
                {"detail": "Payment cannot be changed after order is terminal."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if action == "mark_paid":
            if order.payment_method != "cod":
                return Response(
                    {"detail": "Only COD orders can be marked paid manually."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if order.payment_status == "paid":
                return Response(OrderSerializer(order).data)
            order.payment_status = "paid"
            order.payment_id = order.payment_id or f"COD-{order.order_number}"
            order.save(update_fields=["payment_status", "payment_id", "updated_at"])
            _broadcast_order(order)
            return Response(OrderSerializer(order).data)

        if action == "send_notification":
            if order.payment_method != "online" or order.payment_status != "pending":
                return Response(
                    {
                        "detail": "Payment notification is only for Online | Pending orders."
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )
            # Resolved NameError bug: calling send_pending_online_payment_reminder correctly
            send_pending_online_payment_reminder(order.id)
            return Response(
                {
                    "detail": "Payment notification sent.",
                    "order": OrderSerializer(order).data,
                }
            )

        method = serializer.validated_data.get("payment_method")
        if not method:
            return Response(
                {"detail": "payment_method is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if order.payment_status == "paid":
            return Response(
                {"detail": "Payment method cannot be changed after payment is paid."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order.payment_method = method
        order.payment_status = "pending"
        if method == "cod":
            order.cashfree_order_id = ""
            order.payment_session_id = ""
        order.save(
            update_fields=[
                "payment_method",
                "payment_status",
                "cashfree_order_id",
                "payment_session_id",
                "updated_at",
            ]
        )
        _broadcast_order(order)
        return Response(OrderSerializer(order).data)
