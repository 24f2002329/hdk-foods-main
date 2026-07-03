import logging
from decimal import Decimal
from django.utils import timezone
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated

from accounts.models import Address
from authentication.permissions import IsCustomer
from authentication.firebase import send_push
from orders.models import Coupon, Order, OrderItem, PrepConfig
from orders.serializers import (
    OrderCreateSerializer,
    OrderSerializer,
    AcknowledgeChangesSerializer,
    CouponSerializer,
)
from config.logging import bind_log_context
from .websocket import _broadcast_order

logger = logging.getLogger(__name__)


class CreateOrderView(APIView):
    """Customer submits their cart items to initialize a pending order."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        serializer = OrderCreateSerializer(
            data=request.data, context={"request": request}
        )
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        from services.order_service import create_order
        from django.core.exceptions import ValidationError as DjangoValidationError

        try:
            order = create_order(
                user=request.user,
                address_id=data["address_id"],
                items=data["items"],
                payment_method=data.get("payment_method") or "cod",
                delivery_notes=data.get("delivery_notes", ""),
                coupon_code=data.get("coupon_code", ""),
                redeem_coins=bool(request.data.get("redeem_coins", False)),
            )
        except DjangoValidationError as e:
            return Response(
                {"detail": str(e.message if hasattr(e, "message") else e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)


from rest_framework.pagination import PageNumberPagination


class OrderPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


class MyOrdersView(generics.ListAPIView):
    serializer_class = OrderSerializer
    pagination_class = OrderPagination
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Order.objects.filter(user=self.request.user).order_by("-created_at")


class OrderDetailView(generics.RetrieveAPIView):
    queryset = Order.objects.all()
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_object(self):
        obj = super().get_object()
        # RBAC Check: Only the placing customer, assigned driver, or admin can track details
        if not (
            self.request.user == obj.user
            or self.request.user == obj.assigned_delivery
            or self.request.user.role == "admin"
        ):
            from rest_framework.exceptions import PermissionDenied

            raise PermissionDenied(
                "You do not have permission to view this order's details."
            )
        return obj


class QueuePositionView(APIView):
    """Retrieve the customer's real-time queue position based on active pending orders."""

    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
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

        # If order is no longer in pending_confirmation state, position is 0
        if order.status != "pending_confirmation":
            return Response({"position": 0, "active_ahead": 0})

        # Calculate position based on creation timestamp
        active_ahead = Order.objects.filter(
            status="pending_confirmation", created_at__lt=order.created_at
        ).count()

        position = active_ahead + 1

        return Response({"position": position, "active_ahead": active_ahead})


class RequestCancellationView(APIView):
    """Customer requests to cancel the order.

    If pending_confirmation -> cancels immediately.
    Else -> flags request, restaurant admin must approve.
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

        if order.status == "pending_confirmation":
            order.status = "cancelled"
            order.cancellation_reason = "Customer cancelled before confirmation"
            order.save(update_fields=["status", "cancellation_reason", "updated_at"])
            _broadcast_order(order)
            return Response(OrderSerializer(order).data)

        if order.status in ("cancelled", "rejected", "delivered"):
            return Response(
                {"detail": "Cannot cancel order in terminal state."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order.cancellation_requested = True
        order.cancellation_reason = request.data.get("reason", "No reason provided")
        order.save(
            update_fields=[
                "cancellation_requested",
                "cancellation_reason",
                "updated_at",
            ]
        )
        _broadcast_order(order)

        return Response(
            {
                "detail": "Cancellation request submitted. Awaiting staff approval.",
                "order": OrderSerializer(order).data,
            }
        )


class ReportNotReceivedView(APIView):
    """Customer reports order not received after marked delivered."""

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND
            )

        if order.user != request.user:
            return Response(
                {"detail": "Not your order."}, status=status.HTTP_403_FORBIDDEN
            )

        if order.status != "delivered":
            return Response(
                {"detail": "You can only report non-receipt for delivered orders."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if order.not_received_reported:
            return Response(
                {"detail": "Already reported."}, status=status.HTTP_400_BAD_REQUEST
            )

        order.not_received_reported = True
        order.not_received_reported_at = timezone.now()
        order.save(update_fields=["not_received_reported", "not_received_reported_at"])

        # Alert admin via push notification
        from authentication.firebase import send_push_to_role

        try:
            send_push_to_role(
                "admin",
                f"⚠️ Order Not Received – #{order.order_number}",
                f"{order.user.name or order.user.phone_number} says they didn't receive their order.",
                data={"order_id": str(order.id), "type": "order"},
            )
        except Exception as e:
            logger.warning(f"Could not send not-received push: {e}")

        # Broadcast updated order so admin dashboard refreshes
        _broadcast_order(order)

        return Response(OrderSerializer(order).data)


class AcknowledgeChangesView(APIView):
    """Customer acknowledges that order items were modified by admin."""

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

        serializer = AcknowledgeChangesSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        approve = serializer.validated_data["approve"]

        if not order.items_modified:
            return Response(
                {"detail": "No modifications pending acknowledgment."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if approve:
            # Confirm changes: Reset modification flag, lock in new totals
            order.items_modified = False
            order.save(update_fields=["items_modified", "updated_at"])
            _broadcast_order(order)
            return Response(
                {
                    "detail": "Modifications approved.",
                    "order": OrderSerializer(order).data,
                }
            )
        else:
            # Reject changes: Cancel the order
            order.status = "cancelled"
            order.items_modified = False
            order.cancellation_reason = "Customer rejected order modifications."
            order.save(
                update_fields=[
                    "status",
                    "items_modified",
                    "cancellation_reason",
                    "updated_at",
                ]
            )

            # Initiate Cashfree refund if payment was online & paid
            from .payment import initiate_cashfree_refund

            refunded = False
            if order.payment_method == "online" and order.payment_status == "paid":
                refunded = initiate_cashfree_refund(order, order.cancellation_reason)

            _broadcast_order(order)
            return Response(
                {
                    "detail": "Modifications rejected. Order cancelled.",
                    "refund_initiated": refunded,
                    "order": OrderSerializer(order).data,
                }
            )


class ActiveCouponListView(generics.ListAPIView):
    """List all coupons currently active for customers."""

    serializer_class = CouponSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Coupon.objects.filter(is_active=True).order_by("-created_at")


class ValidateCouponView(APIView):
    """Validate coupon code and return discount amount."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        code = request.data.get("code")
        order_total_str = request.data.get("order_total")

        if not code or not order_total_str:
            return Response(
                {"detail": "Both code and order_total are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            order_total = Decimal(order_total_str)
            coupon = Coupon.objects.get(code__iexact=code, is_active=True)

            if order_total < coupon.min_order_amount:
                return Response(
                    {
                        "valid": False,
                        "detail": f"Coupon requires a minimum order of ₹{coupon.min_order_amount}",
                    }
                )

            discount = Decimal("0.00")
            if coupon.discount_type == "flat":
                discount = coupon.discount_value
            elif coupon.discount_type == "percentage":
                discount = (order_total * coupon.discount_value) / Decimal("100.00")

            if discount > order_total:
                discount = order_total

            return Response(
                {
                    "valid": True,
                    "discount_amount": str(discount),
                    "code": coupon.code,
                }
            )

        except Coupon.DoesNotExist:
            return Response({"valid": False, "detail": "Invalid or inactive coupon."})
        except Exception as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)
