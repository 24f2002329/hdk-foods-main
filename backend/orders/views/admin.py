import logging
from decimal import Decimal
from django.utils import timezone
from django.db.models import Q
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated
from rest_framework.pagination import PageNumberPagination

from accounts.models import Address, User
from products.models import Product
from orders.models import Coupon, Order, OrderItem, PrepConfig
from orders.serializers import (
    OrderSerializer,
    ConfirmOrderSerializer,
    RejectOrderSerializer,
    AssignDeliverySerializer,
    ApplyDiscountSerializer,
    UpdateStatusSerializer,
    PrepConfigSerializer,
    CouponSerializer,
    CouponWriteSerializer,
)
from authentication.permissions import IsAdmin
from authentication.firebase import send_push, send_push_to_role
from config.logging import bind_log_context
from .websocket import _broadcast_order
from .delivery import _delivery_block_reason

logger = logging.getLogger(__name__)


class OrderPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


class OrderListView(generics.ListAPIView):
    queryset = Order.objects.all().order_by("-created_at")
    serializer_class = OrderSerializer
    permission_classes = [IsAdmin]
    pagination_class = OrderPagination

    def get_queryset(self):
        queryset = super().get_queryset()
        status_filter = self.request.query_params.get("status")
        if status_filter:
            queryset = queryset.filter(status=status_filter)
        return queryset


class PendingOrdersView(generics.ListAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        return Order.objects.filter(status="pending_confirmation").order_by(
            "created_at"
        )


class ConfirmOrderView(APIView):
    permission_classes = [IsAdmin]

    def patch(self, request, pk):
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

        if order.status != "pending_confirmation":
            return Response(
                {"detail": "Only pending orders can be confirmed."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = ConfirmOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        prep_time = serializer.validated_data["estimated_preparation_time"]

        from services.order_service import confirm_order

        order = confirm_order(order, prep_time, request.user)

        logger.info(
            f"Confirmed order {order.order_number}: prep_time={prep_time}, "
            f"confirmed_at={order.confirmed_at}"
        )

        return Response(OrderSerializer(order).data)


class RejectOrderView(APIView):
    permission_classes = [IsAdmin]

    def patch(self, request, pk):
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

        if order.status != "pending_confirmation":
            return Response(
                {"detail": "Only pending orders can be rejected."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = RejectOrderSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        reason = serializer.validated_data["reason"]

        from services.order_service import reject_order

        order = reject_order(order, reason)

        logger.info(
            f"Rejected order {order.order_number}: reason={reason}, "
            f"refund_status={order.refund_status}"
        )

        return Response(OrderSerializer(order).data)


class UpdateOrderStatusView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
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

        serializer = UpdateStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_status = serializer.validated_data["status"]

        from services.order_service import update_order_status

        try:
            order = update_order_status(order, new_status, request.user)
        except PermissionError as e:
            return Response({"detail": str(e)}, status=status.HTTP_403_FORBIDDEN)
        except ValueError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(OrderSerializer(order).data)


class AssignDeliveryView(APIView):
    permission_classes = [IsAdmin]

    def patch(self, request, pk):
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

        serializer = AssignDeliverySerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        delivery_user_id = serializer.validated_data["delivery_user_id"]

        from services.order_service import assign_delivery_user
        from django.core.exceptions import ValidationError as DjangoValidationError

        try:
            order = assign_delivery_user(order, delivery_user_id)
        except DjangoValidationError as e:
            return Response(
                {"detail": str(e.message if hasattr(e, "message") else e)},
                status=status.HTTP_404_NOT_FOUND,
            )

        return Response(OrderSerializer(order).data)


class ApplyDiscountView(APIView):
    """Chef or admin applies a flat rupee discount to an order."""

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
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

        if order.status in ("delivered", "cancelled", "rejected"):
            return Response(
                {"detail": "Cannot apply discount to a completed order."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = ApplyDiscountSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        discount = serializer.validated_data["discount_amount"]
        reason = serializer.validated_data.get("discount_reason", "")

        from services.order_service import apply_discount

        try:
            order = apply_discount(order, discount, reason, request.user)
        except ValueError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        return Response(OrderSerializer(order).data)


class EditOrderItemsView(APIView):
    """Chef or admin edits order items before confirmation."""

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND
            )

        items_data = request.data.get("items", [])
        if not items_data:
            return Response(
                {"detail": "At least one item is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from services.order_service import edit_order_items
        from django.core.exceptions import ValidationError as DjangoValidationError

        try:
            order = edit_order_items(order, items_data, request.user)
        except DjangoValidationError as e:
            return Response(
                {"detail": str(e.message if hasattr(e, "message") else e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(OrderSerializer(order).data)


from services.order_service import normalize_phone_number


class AdminCreateOrderView(APIView):
    """Admin manually places an order for a customer by their phone number."""

    permission_classes = [IsAdmin]

    def post(self, request):
        phone_number = request.data.get("phone_number", "").strip()
        customer_name = request.data.get("customer_name", "").strip()
        delivery_type = request.data.get("delivery_type", "delivery")
        address_text = request.data.get("address_text", "").strip()
        address_id = request.data.get("address_id")

        house = request.data.get("house", "").strip()
        street = request.data.get("street", "").strip()
        landmark = request.data.get("landmark", "").strip()
        city = request.data.get("city", "").strip()
        pincode = request.data.get("pincode", "").strip()

        items = request.data.get("items", [])
        payment_method = request.data.get("payment_method", "cod")
        coupon_code = request.data.get("coupon_code", "").strip()
        delivery_notes = request.data.get("delivery_notes", "").strip()

        from services.order_service import admin_create_order
        from django.core.exceptions import ValidationError as DjangoValidationError

        try:
            order = admin_create_order(
                phone_number=phone_number,
                customer_name=customer_name,
                delivery_type=delivery_type,
                address_text=address_text,
                address_id=address_id,
                house=house,
                street=street,
                landmark=landmark,
                city=city,
                pincode=pincode,
                items=items,
                payment_method=payment_method,
                coupon_code=coupon_code,
                delivery_notes=delivery_notes,
            )
        except DjangoValidationError as e:
            return Response(
                {"detail": str(e.message if hasattr(e, "message") else e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)


class AdminHandleCancellationView(APIView):
    """Admin: Approve or decline a cancellation request."""

    permission_classes = [IsAdmin]

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

        action = request.data.get("action", "").strip()  # "approve" or "reject"
        reason = request.data.get("reason", "").strip()

        if action not in ["approve", "reject"]:
            return Response(
                {"detail": "Action must be either 'approve' or 'reject'."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from services.order_service import handle_cancellation_request
        from django.core.exceptions import ValidationError as DjangoValidationError

        try:
            order = handle_cancellation_request(order, action, reason)
        except DjangoValidationError as e:
            return Response(
                {"detail": str(e.message if hasattr(e, "message") else e)},
                status=status.HTTP_400_BAD_REQUEST,
            )

        return Response(OrderSerializer(order).data)


class AdminCancelOrderView(APIView):
    """Admin: Cancel order directly at any stage."""

    permission_classes = [IsAdmin]

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

        reason = request.data.get("reason", "").strip()
        if not reason:
            return Response(
                {"detail": "Cancellation reason is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from services.order_service import admin_cancel_order

        order = admin_cancel_order(order, reason)

        return Response(OrderSerializer(order).data)


class AdminOverrideStatusView(APIView):
    """
    Admin can force-set an order to ANY status, bypassing the normal
    delivery-staff-only / step-by-step restrictions.
    """

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

        new_status = request.data.get("status", "").strip()
        valid_statuses = [s[0] for s in Order.STATUS_CHOICES]
        if new_status not in valid_statuses:
            return Response(
                {"detail": f"Invalid status. Choose from: {', '.join(valid_statuses)}"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        old_status = order.status

        # If we're un-delivering (moving away from delivered), reverse earned coins.
        if old_status == "delivered" and new_status != "delivered":
            if order.coins_earned > 0:
                customer = order.user
                customer.loyalty_coins = max(
                    0, getattr(customer, "loyalty_coins", 0) - order.coins_earned
                )
                customer.save(update_fields=["loyalty_coins"])
                order.coins_earned = 0

        # If we're re-delivering (moving to delivered from non-delivered), award coins.
        if new_status == "delivered" and old_status != "delivered":
            block_reason = _delivery_block_reason(order)
            if block_reason:
                return Response(
                    {"detail": block_reason},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            from app_config.models import SiteConfig

            percentage = SiteConfig.get().loyalty_coins_percentage
            earned = int((order.total_amount * percentage) // 100)
            if earned > 0:
                customer = order.user
                customer.loyalty_coins = getattr(customer, "loyalty_coins", 0) + earned
                customer.save(update_fields=["loyalty_coins"])
                order.coins_earned = earned

        # If overriding away from delivered, also clear not_received flag
        if old_status == "delivered" and new_status != "delivered":
            order.not_received_reported = False
            order.not_received_reported_at = None

        order.status = new_status
        order.save()

        # Push notification to customer
        _push_map = {
            "preparing": (
                "Kitchen is preparing your order 👨‍🍳",
                "Your food is being freshly prepared!",
            ),
            "out_for_delivery": (
                "On the way! 🛵",
                f"Order #{order.order_number} is out for delivery.",
            ),
            "delivered": (
                "Order Delivered! 🎉",
                "Rate your food and share your feedback ⭐",
            ),
            "confirmed": (
                "Order Confirmed ✅",
                f"Your order #{order.order_number} has been confirmed.",
            ),
        }
        if new_status in _push_map:
            title, body = _push_map[new_status]
            send_push(
                order.user, title, body, {"order_id": str(order.id), "type": "order"}
            )

        _broadcast_order(order)

        return Response(OrderSerializer(order).data)


class PrepConfigView(APIView):
    """View and update global preparation configuration settings. Admin only."""

    permission_classes = [IsAdmin]

    def get(self, request):
        config = PrepConfig.get()
        return Response(PrepConfigSerializer(config).data)

    def patch(self, request):
        config = PrepConfig.get()
        serializer = PrepConfigSerializer(config, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class CouponListCreateView(APIView):
    """Admin: list all coupons (GET) or create a new one (POST)."""

    permission_classes = [IsAdmin]

    def get(self, request):
        coupons = Coupon.objects.all().order_by("-created_at")
        return Response(CouponSerializer(coupons, many=True).data)

    def post(self, request):
        serializer = CouponWriteSerializer(data=request.data)
        if serializer.is_valid():
            coupon = serializer.save()
            return Response(
                CouponSerializer(coupon).data, status=status.HTTP_201_CREATED
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CouponDetailView(APIView):
    """Admin: update (PATCH) or delete a coupon."""

    permission_classes = [IsAdmin]

    def _get(self, pk):
        try:
            return Coupon.objects.get(pk=pk)
        except Coupon.DoesNotExist:
            return None

    def patch(self, request, pk):
        coupon = self._get(pk)
        if not coupon:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = CouponWriteSerializer(coupon, data=request.data, partial=True)
        if serializer.is_valid():
            coupon = serializer.save()
            return Response(CouponSerializer(coupon).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        coupon = self._get(pk)
        if not coupon:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        coupon.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CouponToggleView(APIView):
    """Admin: toggle a coupon's is_active flag."""

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            coupon = Coupon.objects.get(pk=pk)
        except Coupon.DoesNotExist:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        coupon.is_active = not coupon.is_active
        coupon.save(update_fields=["is_active"])
        return Response(CouponSerializer(coupon).data)
