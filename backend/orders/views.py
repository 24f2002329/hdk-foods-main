# from django.shortcuts import render

# Create your views here.

from decimal import Decimal
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import Address, User
from authentication.permissions import (
    IsAdmin,
    IsDelivery
)
from products.models import Product

from authentication.permissions import IsCustomer
from authentication.firebase import send_push
from .models import Order, OrderItem, OrderReview
from .serializers import (
    AcknowledgeChangesSerializer,
    ApplyDiscountSerializer,
    AssignDeliverySerializer,
    ConfirmOrderSerializer,
    OrderCreateSerializer,
    OrderSerializer,
    RejectOrderSerializer,
    SelectPaymentSerializer,
    UpdateStatusSerializer
)

from django.utils import timezone
from datetime import timedelta

from django.db.models import Sum

from rest_framework.permissions import IsAuthenticated, AllowAny

from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator

import uuid
import requests
import logging
import hmac
import hashlib

logger = logging.getLogger(__name__)



class CreateOrderView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    def post(self, request):

        serializer = OrderCreateSerializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        data = serializer.validated_data

        address = Address.objects.get(
            id=data["address_id"],
            user=request.user
        )

        total_amount = Decimal("0.00")

        order = Order.objects.create(
            user=address.user,
            address=address,
            payment_method=data.get(
                "payment_method"
            ) or "cod",
            delivery_notes=data.get(
                "delivery_notes",
                ""
            ),
            total_amount=0
        )

        for item in data["items"]:

            product = Product.objects.get(
                id=item["product_id"]
            )

            quantity = item["quantity"]

            price = product.price

            total_amount += (
                price * quantity
            )

            OrderItem.objects.create(
                order=order,
                product=product,
                quantity=quantity,
                price=price
            )

        order.total_amount = total_amount
        order.save()

        return Response(
            OrderSerializer(order).data,
            status=status.HTTP_201_CREATED
        )



class SelectPaymentView(APIView):
    """Customer selects payment method after the order is confirmed.

    cod    -> mark method, order proceeds straight to tracking.
    online -> create a Cashfree order and return the checkout params.
    """

    permission_classes = [
        IsAuthenticated
    ]

    def post(self, request, pk):

        try:
            order = Order.objects.get(
                pk=pk,
                user=request.user
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        if order.status != "confirmed":
            return Response(
                {
                    "detail":
                        "Order must be confirmed "
                        "before payment."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if order.payment_status == "paid":
            return Response(
                {"detail": "Order already paid."},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = SelectPaymentSerializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        method = serializer.validated_data[
            "payment_method"
        ]

        if method == "cod":
            order.payment_method = "cod"
            order.payment_status = "pending"
            order.save(
                update_fields=[
                    "payment_method",
                    "payment_status",
                    "updated_at"
                ]
            )

            return Response(
                {
                    "payment_method": "cod",
                    "order":
                        OrderSerializer(order).data
                }
            )

        # online -> Cashfree
        if not settings.CASHFREE_APP_ID or \
                not settings.CASHFREE_SECRET_KEY:
            return Response(
                {
                    "detail":
                        "Online payment is not "
                        "configured."
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )

        # Cashfree expects the amount in rupees (not paise) and a globally
        # unique order id. A failed attempt leaves its order behind on
        # Cashfree, so each attempt gets a fresh id derived from our
        # order_number to avoid an "order_already_exists" collision on retry.
        cf_order_id = (
            f"{order.order_number}_"
            f"{uuid.uuid4().hex[:10]}"
        )

        logger.info(
            f"Creating Cashfree order: cf_order_id={cf_order_id}, "
            f"amount={order.total_amount}, user_id={request.user.id}"
        )

        try:
            cf_response = requests.post(
                f"{settings.CASHFREE_BASE_URL}/orders",
                headers={
                    "x-client-id":
                        settings.CASHFREE_APP_ID,
                    "x-client-secret":
                        settings.CASHFREE_SECRET_KEY,
                    "x-api-version":
                        settings.CASHFREE_API_VERSION,
                    "Content-Type":
                        "application/json",
                },
                json={
                    "order_id": cf_order_id,
                    "order_amount": float(
                        order.total_amount
                    ),
                    "order_currency": "INR",
                    "customer_details": {
                        "customer_id":
                            str(request.user.id),
                        "customer_phone":
                            request.user.phone_number,
                        "customer_name":
                            request.user.name or "Customer",
                    },
                },
                timeout=15
            )
        except requests.RequestException:
            return Response(
                {
                    "detail":
                        "Could not reach payment "
                        "gateway."
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        if cf_response.status_code not in (200, 201):
            return Response(
                {
                    "detail":
                        "Payment gateway error.",
                    "gateway":
                        cf_response.text
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        cf_order = cf_response.json()

        order.payment_method = "online"
        order.cashfree_order_id = cf_order_id
        order.payment_session_id = cf_order[
            "payment_session_id"
        ]
        # A new attempt supersedes any prior failed one.
        if order.payment_status == "failed":
            order.payment_status = "pending"
        order.save(
            update_fields=[
                "payment_method",
                "cashfree_order_id",
                "payment_session_id",
                "payment_status",
                "updated_at"
            ]
        )

        return Response(
            {
                "payment_method": "online",
                "payment_session_id":
                    cf_order["payment_session_id"],
                "cf_order_id":
                    cf_order_id,
                "environment":
                    settings.CASHFREE_ENV,
                "order":
                    OrderSerializer(order).data
            }
        )


class VerifyPaymentView(APIView):
    """Confirm payment with Cashfree and mark the order paid.

    Cashfree does not hand the client a signature to verify. Instead we
    fetch the order's status from Cashfree (server-to-server) and trust
    only ``order_status == "PAID"``.
    """

    permission_classes = [
        IsAuthenticated
    ]

    def post(self, request, pk):

        try:
            order = Order.objects.get(
                pk=pk,
                user=request.user
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        # No online attempt has been started for this order yet.
        if not order.cashfree_order_id:
            return Response(
                {
                    "payment_status":
                        order.payment_status,
                    "order":
                        OrderSerializer(order).data
                }
            )

        try:
            cf_response = requests.get(
                f"{settings.CASHFREE_BASE_URL}"
                f"/orders/{order.cashfree_order_id}",
                headers={
                    "x-client-id":
                        settings.CASHFREE_APP_ID,
                    "x-client-secret":
                        settings.CASHFREE_SECRET_KEY,
                    "x-api-version":
                        settings.CASHFREE_API_VERSION,
                },
                timeout=15
            )
        except requests.RequestException:
            return Response(
                {
                    "detail":
                        "Could not reach payment "
                        "gateway."
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        if cf_response.status_code != 200:
            return Response(
                {
                    "detail":
                        "Payment gateway error.",
                    "gateway":
                        cf_response.text
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        cf_order = cf_response.json()
        order_status = cf_order.get(
            "order_status"
        )

        logger.info(
            f"Verified Cashfree payment: order_id={order.id}, "
            f"cf_order_id={order.cashfree_order_id}, status={order_status}"
        )

        # PAID                 -> success
        # EXPIRED/TERMINATED   -> terminal failure
        # ACTIVE (and others)  -> still awaiting payment; leave pending so
        #                         this endpoint is safe to poll repeatedly.
        if order_status == "PAID":
            order.payment_status = "paid"
            order.payment_id = str(
                cf_order.get("cf_order_id", "")
            )
            order.save(
                update_fields=[
                    "payment_status",
                    "payment_id",
                    "updated_at"
                ]
            )

            return Response(
                {
                    "payment_status": "paid",
                    "order":
                        OrderSerializer(order).data
                }
            )

        if order_status in ("EXPIRED", "TERMINATED"):
            order.payment_status = "failed"
            order.save(
                update_fields=[
                    "payment_status",
                    "updated_at"
                ]
            )

        return Response(
            {
                "payment_status":
                    order.payment_status,
                "order_status":
                    order_status,
                "order":
                    OrderSerializer(order).data
            }
        )



class OrderListView(generics.ListAPIView):

    queryset = Order.objects.all().order_by(
        "-created_at"
    )

    serializer_class = OrderSerializer
    permission_classes = [IsAdmin]



class MyOrdersView(generics.ListAPIView):
    serializer_class = OrderSerializer
    
    permission_classes = [
        IsAuthenticated
    ]

    def get_queryset(self):
        return Order.objects.filter(
            user=self.request.user
        ).order_by(
            "-created_at"
        )


class OrderDetailView(generics.RetrieveAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if hasattr(user, 'role') and user.role in ('admin', 'delivery'):
            return Order.objects.all()
        return Order.objects.filter(user=user)
    


class ConfirmOrderView(APIView):

    permission_classes = [
        IsAdmin
    ]

    def patch(self, request, pk):

        try:
            order = Order.objects.get(
                pk=pk
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = (
            ConfirmOrderSerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        prep_time = serializer.validated_data[
            "estimated_preparation_time"
        ]

        order.status = "confirmed"

        order.confirmed_at = (
            timezone.now()
        )

        order.estimated_preparation_time = (
            prep_time
        )

        order.estimated_delivery_time = (
            timezone.now()
            + timedelta(
                minutes=prep_time + 15
            )
        )

        order.confirmed_by = request.user
        order.save()

        send_push(
            order.user,
            "Order Confirmed ✅",
            f"Your order #{order.order_number} is confirmed! Ready in ~{prep_time} mins.",
            {"order_id": str(order.id)},
        )

        return Response(
            OrderSerializer(order).data
        )


class RejectOrderView(APIView):

    permission_classes = [
        IsAdmin
    ]
    
    def patch(self, request, pk):

        try:
            order = Order.objects.get(
                pk=pk
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = (
            RejectOrderSerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        order.status = "rejected"

        order.rejection_reason = (
            serializer.validated_data[
                "reason"
            ]
        )

        order.save()

        send_push(
            order.user,
            "Order Rejected ❌",
            f"Order #{order.order_number} was rejected. Sorry for the inconvenience.",
            {"order_id": str(order.id)},
        )

        return Response(
            OrderSerializer(order).data
        )




class UpdateOrderStatusView(APIView):

    permission_classes = [
        IsAdmin
    ]

    def patch(self, request, pk):

        try:
            order = Order.objects.get(
                pk=pk
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = (
            UpdateStatusSerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        new_status = serializer.validated_data["status"]
        order.status = new_status
        order.save()

        _push_map = {
            "preparing": ("Kitchen is preparing your order 👨‍🍳", "Your food is being freshly prepared!"),
            "out_for_delivery": ("On the way! 🛵", f"Order #{order.order_number} is out for delivery."),
            "delivered": ("Order Delivered! 🎉", "Rate your food and share your feedback ⭐"),
        }
        if new_status in _push_map:
            title, body = _push_map[new_status]
            send_push(order.user, title, body, {"order_id": str(order.id)})

        return Response(
            OrderSerializer(order).data
        )



class AssignDeliveryView(APIView):

    permission_classes = [
        IsAdmin
    ]

    def patch(
        self,
        request,
        pk
    ):

        try:
            order = Order.objects.get(
                pk=pk
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = (
            AssignDeliverySerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        try:
            delivery_user = User.objects.get(
                id=serializer.validated_data[
                    "delivery_user_id"
                ],
                role="delivery"
            )
        except User.DoesNotExist:
            return Response(
                {
                    "detail":
                        "Delivery user not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        order.assigned_delivery = delivery_user
        order.save()

        send_push(
            delivery_user,
            "New Delivery Assigned 🛵",
            f"Order #{order.order_number} has been assigned to you.",
            {"order_id": str(order.id)},
        )

        return Response(
            OrderSerializer(order).data
        )
    

class DeliveryOrdersView(generics.ListAPIView):

    serializer_class = (
        OrderSerializer
    )

    permission_classes = [
        IsDelivery
    ]

    def get_queryset(self):

        return Order.objects.filter(
            assigned_delivery=
            self.request.user
        ).order_by(
            "-created_at"
        )


class PendingOrdersView(generics.ListAPIView):

    serializer_class = (
        OrderSerializer
    )

    permission_classes = [
        IsAdmin
    ]

    def get_queryset(self):

        return Order.objects.filter(
            status=
            "pending_confirmation"
        ).order_by(
            "created_at"
        )






class AdminDashboardView(APIView):

    permission_classes = [IsAdmin]

    def get(
        self,
        request
    ):

        today = (
            timezone.now()
            .date()
        )

        today_orders = (
            Order.objects.filter(
                created_at__date=today
            )
            .count()
        )

        pending_orders = (
            Order.objects.filter(
                status=
                "pending_confirmation"
            )
            .count()
        )

        active_deliveries = (
            Order.objects.filter(
                status=
                "out_for_delivery"
            )
            .count()
        )

        today_revenue = (
            Order.objects.filter(
                created_at__date=today,
                payment_status="paid"
            )
            .aggregate(total=Sum("total_amount"))["total"]
            or 0
        )

        in_progress = Order.objects.filter(
            status__in=["confirmed", "preparing", "ready_for_pickup"]
        ).count()

        delivered_today = Order.objects.filter(
            created_at__date=today,
            status="delivered"
        ).count()

        return Response(
            {
                "today_orders": today_orders,
                "pending_orders": pending_orders,
                "in_progress": in_progress,
                "active_deliveries": active_deliveries,
                "delivered_today": delivered_today,
                "today_revenue": today_revenue,
            }
        )


# @method_decorator(csrf_exempt, name="dispatch")
# class CashfreeWebhookView(APIView):
#     """
#     Receive server-to-server payment notifications from Cashfree.

#     Cashfree sends a POST with x-webhook-signature header (HMAC-SHA256).
#     On PAYMENT_SUCCESS_WEBHOOK, mark the order as paid.
#     """
#     permission_classes = [AllowAny]

#     def post(self, request):
#         # Get the signature from the header
#         signature = request.META.get(
#             "HTTP_X_WEBHOOK_SIGNATURE",
#             ""
#         )

#         # Verify signature against webhook secret
#         if not settings.CASHFREE_WEBHOOK_SECRET:
#             logger.warning(
#                 "Webhook received but CASHFREE_WEBHOOK_SECRET not configured"
#             )
#             return Response(
#                 {"detail": "Webhook not configured."},
#                 status=status.HTTP_503_SERVICE_UNAVAILABLE
#             )

#         # The payload body is what we sign
#         raw_body = request.body

#         expected_signature = hmac.new(
#             settings.CASHFREE_WEBHOOK_SECRET.encode(),
#             raw_body,
#             hashlib.sha256
#         ).hexdigest()

#         if not hmac.compare_digest(
#             signature,
#             expected_signature
#         ):
#             logger.warning(
#                 f"Webhook signature mismatch. "
#                 f"Expected: {expected_signature}, Got: {signature}"
#             )
#             return Response(
#                 {"detail": "Signature verification failed."},
#                 status=status.HTTP_400_BAD_REQUEST
#             )

#         # Parse the payload
#         try:
#             data = request.data
#         except Exception as e:
#             logger.error(
#                 f"Failed to parse webhook payload: {e}"
#             )
#             return Response(
#                 {"detail": "Invalid payload."},
#                 status=status.HTTP_400_BAD_REQUEST
#             )

#         event_type = data.get("event_type", "")
#         event_data = data.get("data", {})

#         logger.info(
#             f"Webhook received: event_type={event_type}, "
#             f"order_id={event_data.get('order', {}).get('order_id', '')}"
#         )

#         # Handle payment success
#         if event_type == "PAYMENT_SUCCESS_WEBHOOK":
#             order_id_str = event_data.get(
#                 "order",
#                 {}
#             ).get("order_id", "")

#             # order_id_str is the cf_order_id (e.g. "HDK1001_abc123")
#             if not order_id_str:
#                 logger.warning(
#                     "PAYMENT_SUCCESS_WEBHOOK received without order_id"
#                 )
#                 return Response({}, status=status.HTTP_200_OK)

#             try:
#                 # The cf_order_id contains our order_number prefix, extract it
#                 # Format: {order_number}_{uuid_suffix}
#                 order_number = "_".join(
#                     order_id_str.split("_")[:-1]
#                 )

#                 order = Order.objects.get(
#                     order_number=order_number
#                 )
#             except Order.DoesNotExist:
#                 logger.warning(
#                     f"Webhook for non-existent order: {order_id_str}"
#                 )
#                 # Still return 200 so Cashfree doesn't retry
#                 return Response({}, status=status.HTTP_200_OK)

#             # Mark as paid
#             cf_payment_id = event_data.get(
#                 "payment",
#                 {}
#             ).get("cf_payment_id", "")

#             order.payment_status = "paid"
#             order.payment_id = cf_payment_id
#             order.save(
#                 update_fields=[
#                     "payment_status",
#                     "payment_id",
#                     "updated_at"
#                 ]
#             )

#             logger.info(
#                 f"Order marked as paid via webhook: "
#                 f"order_id={order.id}, cf_order_id={order_id_str}"
#             )

#         # Return 200 for all valid signatures (to prevent Cashfree retries)
#         return Response({}, status=status.HTTP_200_OK)










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

            logger.info(
                "Webhook payload:\n%s",
                json.dumps(data, indent=2)
            )

            event_type = data.get("type", "")
            event_data = data.get("data", {})

            logger.info(
                f"Webhook received: type={event_type}"
            )

            # -------------------------
            # PAYMENT SUCCESS
            # -------------------------
            if event_type == "PAYMENT_SUCCESS_WEBHOOK":

                order_id_str = (
                    event_data.get("order", {})
                    .get("order_id", "")
                )

                cf_payment_id = (
                    event_data.get("payment", {})
                    .get("cf_payment_id", "")
                )

                if not order_id_str:
                    logger.warning(
                        "PAYMENT_SUCCESS_WEBHOOK received without order_id"
                    )
                    return Response(
                        {"status": "success"},
                        status=status.HTTP_200_OK
                    )

                try:
                    order_number = "_".join(
                        order_id_str.split("_")[:-1]
                    )

                    order = Order.objects.get(
                        order_number=order_number
                    )

                    order.payment_status = "paid"
                    order.payment_id = str(cf_payment_id)

                    order.save(
                        update_fields=[
                            "payment_status",
                            "payment_id",
                            "updated_at"
                        ]
                    )

                    logger.info(
                        f"Order marked PAID via webhook: "
                        f"{order.order_number}"
                    )

                except Order.DoesNotExist:
                    logger.warning(
                        f"Order not found: {order_id_str}"
                    )

            # -------------------------
            # PAYMENT FAILED
            # -------------------------
            elif event_type == "PAYMENT_FAILED_WEBHOOK":

                order_id_str = (
                    event_data.get("order", {})
                    .get("order_id", "")
                )

                logger.warning(
                    f"Payment failed for order: {order_id_str}"
                )

                try:
                    order_number = "_".join(
                        order_id_str.split("_")[:-1]
                    )

                    order = Order.objects.get(
                        order_number=order_number
                    )

                    order.payment_status = "failed"

                    order.save(
                        update_fields=[
                            "payment_status",
                            "updated_at"
                        ]
                    )

                except Order.DoesNotExist:
                    logger.warning(
                        f"Order not found: {order_id_str}"
                    )

            else:
                logger.info(
                    f"Ignoring webhook type: {event_type}"
                )

            return Response(
                {"status": "success"},
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.exception(
                f"Webhook processing failed: {str(e)}"
            )

            return Response(
                {
                    "status": "error",
                    "message": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class ApplyDiscountView(APIView):
    """Chef or admin applies a flat rupee discount to an order.

    Re-bases off original_total so a second discount doesn't double-stack.
    Sets is_modified_by_staff so the customer sees the change popup.
    """

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        if order.status in ("delivered", "cancelled", "rejected"):
            return Response(
                {"detail": "Cannot apply discount to a completed order."},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = ApplyDiscountSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        discount = data["discount_amount"]
        reason = data.get("discount_reason", "")

        # Snapshot the pre-discount total once (never overwrite it).
        if order.original_total is None:
            order.original_total = order.total_amount

        if discount > order.original_total:
            return Response(
                {"detail": "Discount cannot exceed the original order total."},
                status=status.HTTP_400_BAD_REQUEST
            )

        order.discount_amount = discount
        order.discount_reason = reason
        order.total_amount = order.original_total - discount
        order.is_modified_by_staff = True
        order.save(update_fields=[
            "discount_amount", "discount_reason",
            "total_amount", "original_total",
            "is_modified_by_staff", "updated_at"
        ])

        logger.info(
            f"Discount applied: order_id={order.id}, "
            f"discount={discount}, reason='{reason}', "
            f"new_total={order.total_amount}, user_id={request.user.id}"
        )

        return Response(OrderSerializer(order).data)


class AcknowledgeChangesView(APIView):
    """Customer accepts or rejects a staff-modified order.

    accepted=true  → clear the notification flag, order continues normally.
    accepted=false → reject the order; customer gets refund message via app.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = AcknowledgeChangesSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        accepted = serializer.validated_data["accepted"]

        if accepted:
            order.is_modified_by_staff = False
            order.save(update_fields=["is_modified_by_staff", "updated_at"])
            logger.info(f"Customer accepted modified order: order_id={order.id}")
        else:
            order.status = "rejected"
            order.rejection_reason = "Customer rejected the modified order."
            order.is_modified_by_staff = False
            order.save(update_fields=[
                "status", "rejection_reason",
                "is_modified_by_staff", "updated_at"
            ])
            logger.info(f"Customer rejected modified order: order_id={order.id}")

        return Response(OrderSerializer(order).data)


class EditOrderItemsView(APIView):
    """Chef or admin edits order items before confirmation.

    Replaces all existing items with the submitted list and recalculates
    total_amount. Only allowed while status == 'pending_confirmation'.
    """

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        if order.status != "pending_confirmation":
            return Response(
                {"detail": "Items can only be edited before confirmation."},
                status=status.HTTP_400_BAD_REQUEST
            )

        items_data = request.data.get("items", [])
        if not items_data:
            return Response(
                {"detail": "At least one item is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Snapshot original total before any modification.
        pre_edit_total = order.total_amount

        # Delete existing items and recalculate.
        order.items.all().delete()
        total_amount = Decimal("0.00")

        for item in items_data:
            try:
                product = Product.objects.get(id=item["product_id"])
            except Product.DoesNotExist:
                return Response(
                    {"detail": f"Product {item['product_id']} not found."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            quantity = int(item.get("quantity", 1))
            if quantity < 1:
                continue

            price = product.price
            total_amount += price * quantity

            OrderItem.objects.create(
                order=order,
                product=product,
                quantity=quantity,
                price=price,
            )

        # Persist total + flag the modification.
        if order.original_total is None:
            order.original_total = pre_edit_total
        order.total_amount = total_amount
        order.is_modified_by_staff = True
        order.save(update_fields=[
            "total_amount", "original_total",
            "is_modified_by_staff", "updated_at"
        ])

        logger.info(
            f"Order items edited by staff: order_id={order.id}, "
            f"new_total={total_amount}, user_id={request.user.id}"
        )

        return Response(OrderSerializer(order).data)


class OrderReviewView(APIView):
    """Customer submits or retrieves a review for a delivered order."""

    permission_classes = [IsCustomer]

    def get(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)
        try:
            review = order.review
            return Response({
                "rating": review.rating,
                "comment": review.comment,
                "submitted": True,
            })
        except OrderReview.DoesNotExist:
            return Response({"submitted": False})

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user, status="delivered")
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found or not yet delivered."},
                status=status.HTTP_404_NOT_FOUND,
            )
        if hasattr(order, "review"):
            return Response({"detail": "Review already submitted."}, status=status.HTTP_400_BAD_REQUEST)

        rating = request.data.get("rating")
        comment = request.data.get("comment", "")
        if not rating or not (1 <= int(rating) <= 5):
            return Response({"detail": "Rating must be 1-5."}, status=status.HTTP_400_BAD_REQUEST)

        OrderReview.objects.create(
            order=order,
            customer=request.user,
            rating=int(rating),
            comment=comment,
        )

        # Update product ratings based on all reviews for that product
        from products.models import Product
        from django.db.models import Avg
        for item in order.items.all():
            avg = OrderReview.objects.filter(
                order__items__product=item.product
            ).aggregate(avg=Avg("rating"))["avg"] or 0
            Product.objects.filter(pk=item.product_id).update(rating=round(avg, 1))

        return Response({"detail": "Review submitted. Thank you!"}, status=status.HTTP_201_CREATED)


class QueuePositionView(APIView):
    """Returns this order's position in the pending/confirmed queue."""

    permission_classes = [IsCustomer]

    def get(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if order.status not in ("pending_confirmation", "confirmed"):
            return Response({"position": None, "ahead": 0})

        ahead = Order.objects.filter(
            status__in=("pending_confirmation", "confirmed"),
            created_at__lt=order.created_at,
        ).count()

        return Response({"position": ahead + 1, "ahead": ahead})
