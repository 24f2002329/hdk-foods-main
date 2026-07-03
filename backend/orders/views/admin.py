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

        order.status = "confirmed"
        order.estimated_preparation_time = prep_time
        order.confirmed_at = timezone.now()
        order.save(
            update_fields=[
                "status",
                "estimated_preparation_time",
                "confirmed_at",
                "updated_at",
            ]
        )

        # Notify customer via push notification
        try:
            send_push(
                order.user,
                "Order Confirmed ✅",
                f"Your order #{order.order_number} has been confirmed. "
                f"Prep time: {prep_time} mins.",
                {"order_id": str(order.id), "type": "order"},
            )
        except Exception as e:
            logger.warning(f"Could not send confirmation push: {e}")

        # Broadcast the updated order status
        _broadcast_order(order)

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

        order.status = "rejected"
        order.cancellation_reason = reason
        order.save(update_fields=["status", "cancellation_reason", "updated_at"])

        # Initiate refund if payment was made online
        refunded = False
        if order.payment_method == "online" and order.payment_status == "paid":
            from .payment import initiate_cashfree_refund

            refunded = initiate_cashfree_refund(order, reason)

        # Notify customer
        try:
            send_push(
                order.user,
                "Order Cancelled ❌",
                f"Your order #{order.order_number} has been rejected. Reason: {reason}",
                {"order_id": str(order.id), "type": "order"},
            )
        except Exception as e:
            logger.warning(f"Could not send rejection push: {e}")

        # Broadcast the rejected order status
        _broadcast_order(order)

        logger.info(
            f"Rejected order {order.order_number}: reason={reason}, "
            f"refund_initiated={refunded}"
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

        if order.status != "pending_confirmation":
            return Response(
                {"detail": "Items can only be edited before confirmation."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        items_data = request.data.get("items", [])
        if not items_data:
            return Response(
                {"detail": "At least one item is required."},
                status=status.HTTP_400_BAD_REQUEST,
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
                    status=status.HTTP_400_BAD_REQUEST,
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

        # Check if the existing discount was from a coupon and recalculate/cap it
        discount_amount = order.discount_amount
        if order.discount_reason and order.discount_reason.startswith("Coupon: "):
            coupon_code = order.discount_reason.replace("Coupon: ", "").strip()
            try:
                coupon = Coupon.objects.get(code__iexact=coupon_code)
                if total_amount < coupon.min_order_amount:
                    discount_amount = Decimal("0.00")
                    order.discount_reason = ""
                else:
                    discount_amount = coupon.compute_discount(total_amount)
            except Coupon.DoesNotExist:
                discount_amount = min(discount_amount, total_amount)
        else:
            discount_amount = min(discount_amount, total_amount)

        order.discount_amount = discount_amount
        order.original_total = total_amount
        order.total_amount = total_amount - discount_amount
        order.is_modified_by_staff = True
        order.save(
            update_fields=[
                "total_amount",
                "original_total",
                "discount_amount",
                "discount_reason",
                "is_modified_by_staff",
                "updated_at",
            ]
        )

        logger.info(
            f"Order items edited by staff: order_id={order.id}, "
            f"new_total={total_amount}, user_id={request.user.id}"
        )

        return Response(OrderSerializer(order).data)


def normalize_phone_number(phone):
    phone = phone.strip()
    if not phone:
        return ""
    phone = "".join(c for c in phone if c.isdigit() or c == "+")
    if len(phone) == 10 and phone.isdigit():
        return f"+91{phone}"
    if len(phone) == 12 and phone.startswith("91"):
        return f"+{phone}"
    if phone.startswith("+"):
        return phone
    return phone


class AdminCreateOrderView(APIView):
    """Admin manually places an order for a customer by their phone number."""

    permission_classes = [IsAdmin]

    def post(self, request):
        phone_number = request.data.get("phone_number", "").strip()
        customer_name = request.data.get("customer_name", "").strip()
        delivery_type = request.data.get(
            "delivery_type", "delivery"
        )  # delivery or pickup
        address_text = request.data.get("address_text", "").strip()
        address_id = request.data.get("address_id")

        # Split Address Fields
        house = request.data.get("house", "").strip()
        street = request.data.get("street", "").strip()
        landmark = request.data.get("landmark", "").strip()
        city = request.data.get("city", "").strip()
        pincode = request.data.get("pincode", "").strip()

        items = request.data.get("items", [])
        payment_method = request.data.get("payment_method", "cod")  # cod or prepaid
        coupon_code = request.data.get("coupon_code", "").strip()
        delivery_notes = request.data.get("delivery_notes", "").strip()

        if not phone_number:
            return Response(
                {"detail": "Phone number is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not items:
            return Response(
                {"detail": "At least one item is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # 1. Get or create the User
        normalized_phone = normalize_phone_number(phone_number)
        raw_10_digit = phone_number[-10:] if len(phone_number) >= 10 else phone_number

        user = User.objects.filter(
            Q(phone_number=phone_number)
            | Q(phone_number=normalized_phone)
            | Q(phone_number__endswith=raw_10_digit)
        ).first()

        if user:
            # Normalize user's phone if it wasn't
            if user.phone_number != normalized_phone:
                user.phone_number = normalized_phone
                user.save(update_fields=["phone_number"])
            # Update name if provided (filled)
            if customer_name:
                user.name = customer_name
                user.save(update_fields=["name"])
        else:
            user = User.objects.create_user(
                phone_number=normalized_phone,
                name=customer_name or "Guest Customer",
                role="customer",
            )

        # 2. Get or create Address
        address = None
        if address_id:
            try:
                address = Address.objects.get(user=user, id=address_id)
            except Address.DoesNotExist:
                address = None

        if not address:
            if delivery_type == "pickup":
                house_text = "Store Pickup"
                street_text = ""
                landmark_text = ""
                city_text = "Sojat Road"
                pincode_text = "306103"
            else:
                house_text = house or address_text or "Delivery"
                street_text = street
                landmark_text = landmark
                city_text = city or "Sojat Road"
                pincode_text = pincode or "306103"

            # Find if user already has an address with these exact details
            address = Address.objects.filter(
                user=user,
                house=house_text,
                street=street_text,
                landmark=landmark_text,
                city=city_text,
                pincode=pincode_text,
            ).first()

            if not address:
                address = Address.objects.create(
                    user=user,
                    label="Home" if delivery_type == "delivery" else "Other",
                    house=house_text,
                    street=street_text,
                    landmark=landmark_text,
                    city=city_text,
                    pincode=pincode_text,
                    latitude=Decimal("25.861129"),
                    longitude=Decimal("73.749306"),
                    is_default=True,
                )

        # 3. Calculate total and check coupon
        total_amount = Decimal("0.00")
        coupon = None
        if coupon_code:
            try:
                coupon = Coupon.objects.get(code__iexact=coupon_code, is_active=True)
            except Coupon.DoesNotExist:
                return Response(
                    {"detail": "Invalid or expired coupon code."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        order = Order.objects.create(
            user=user,
            address=address,
            payment_method=payment_method,
            payment_status="paid" if payment_method == "prepaid" else "pending",
            delivery_notes=delivery_notes,
            total_amount=Decimal("0.00"),
            status="confirmed",  # Admin-placed order is auto-confirmed
        )

        for item in items:
            product_id = item.get("product_id")
            quantity = int(item.get("quantity", 1))

            try:
                product = Product.objects.get(id=product_id)
            except Product.DoesNotExist:
                order.delete()
                return Response(
                    {"detail": f"Product with ID {product_id} not found."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            item_price = product.price
            customization_price = Decimal("0.00")
            selections = item.get("selections", [])
            for sel in selections:
                extra = Decimal(str(sel.get("price", 0.0)))
                customization_price += extra

            final_price = item_price + customization_price
            total_amount += final_price * quantity

            OrderItem.objects.create(
                order=order, product=product, quantity=quantity, price=final_price
            )

        order.total_amount = total_amount

        # Apply coupon
        if coupon:
            now = timezone.now()
            if coupon.valid_from and now < coupon.valid_from:
                order.delete()
                return Response(
                    {"detail": "Coupon is not yet valid."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if coupon.valid_until and now > coupon.valid_until:
                order.delete()
                return Response(
                    {"detail": "Coupon has expired."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if coupon.usage_limit and coupon.usage_count >= coupon.usage_limit:
                order.delete()
                return Response(
                    {"detail": "Coupon usage limit reached."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if total_amount < coupon.min_order_amount:
                order.delete()
                return Response(
                    {
                        "detail": f"Minimum order amount for this coupon is ₹{coupon.min_order_amount}."
                    },
                    status=status.HTTP_400_BAD_REQUEST,
                )

            discount = coupon.compute_discount(total_amount)
            order.discount_amount = discount
            order.discount_reason = f"Coupon: {coupon.code}"
            order.original_total = total_amount
            order.total_amount = total_amount - discount
            Coupon.objects.filter(pk=coupon.pk).update(
                usage_count=coupon.usage_count + 1
            )

        order.save()

        # Send push notification to user (if FCM token is available)
        try:
            send_push(
                user,
                "Order Placed 🛍️",
                f"An order has been placed for you: Order #{order.order_number}",
                {"order_id": str(order.id), "type": "order"},
            )
        except Exception as e:
            logger.warning(f"Could not send push notification: {e}")

        # Broadcast to other channels
        _broadcast_order(order, "new_order")

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
