import logging
from decimal import Decimal
from django.utils import timezone
from datetime import timedelta
from django.core.exceptions import ValidationError
from django_q.tasks import schedule
from django_q.models import Schedule
from accounts.models import Address, User
from products.models import Product
from offers.models import Coupon
from orders.models import Order, OrderItem
from payments.models import Payment, PaymentMethod, PaymentStatus
from .notifications import (
    notify_order_confirmed,
    notify_payment_reminder,
    notify_order_rejected,
    notify_new_order,
)

logger = logging.getLogger(__name__)


def send_pending_online_payment_reminder(order_id):
    try:
        order = Order.objects.select_related("user").get(pk=order_id)
    except Order.DoesNotExist:
        return

    if (
        order.payment_method != "online"
        or order.payment_status != "pending"
        or order.status in ("delivered", "cancelled", "rejected")
    ):
        return

    notify_payment_reminder(order)


def _schedule_pending_online_payment_reminder(order_id):
    schedule(
        "services.order_service.send_pending_online_payment_reminder",
        order_id,
        schedule_type=Schedule.ONCE,
        next_run=timezone.now() + timedelta(minutes=5),
    )


def create_order(
    user,
    address_id: int,
    items: list,
    payment_method: str = "cod",
    delivery_notes: str = "",
    coupon_code: str = "",
    redeem_coins: bool = False,
) -> Order:
    """
    Validates store status, address, coupon, subtotal, creates Order and items,
    applies discounts/loyalty coins, issues primary Payment record, and alerts admins.
    """
    from app_config.models import SiteConfig

    config = SiteConfig.get()
    if not config.is_currently_open():
        raise ValidationError(
            config.store_closed_msg or "The kitchen is closed right now."
        )

    try:
        address = Address.objects.get(id=address_id, user=user)
    except Address.DoesNotExist:
        raise ValidationError("Address not found.")

    # Validate coupon early
    coupon = None
    if coupon_code:
        coupon_code = coupon_code.strip()
        try:
            coupon = Coupon.objects.get(code__iexact=coupon_code, is_active=True)
        except Coupon.DoesNotExist:
            raise ValidationError("Invalid or expired coupon code.")

    # Calculate subtotal first to avoid orphan order records on validation failure
    total_amount = Decimal("0.00")
    items_to_create = []
    for item in items:
        try:
            product = Product.objects.get(id=item["product_id"])
        except Product.DoesNotExist:
            raise ValidationError(f"Product with id {item['product_id']} not found.")
        quantity = item["quantity"]
        price = product.price
        total_amount += price * quantity
        items_to_create.append((product, quantity, price))

    # Validate coupon rules
    if coupon:
        now = timezone.now()
        if coupon.valid_from and now < coupon.valid_from:
            raise ValidationError("Coupon is not yet valid.")
        if coupon.valid_until and now > coupon.valid_until:
            raise ValidationError("Coupon has expired.")
        if coupon.usage_limit and coupon.usage_count >= coupon.usage_limit:
            raise ValidationError("Coupon usage limit reached.")
        if total_amount < coupon.min_order_amount:
            raise ValidationError(
                f"Minimum order amount for this coupon is ₹{coupon.min_order_amount}."
            )

    order = Order.objects.create(
        user=user,
        address=address,
        payment_method=payment_method or "cod",
        delivery_notes=delivery_notes,
        total_amount=total_amount,
    )

    for product, quantity, price in items_to_create:
        OrderItem.objects.create(
            order=order, product=product, quantity=quantity, price=price
        )

    if coupon:
        discount = coupon.compute_discount(total_amount)
        order.discount_amount = discount
        order.discount_reason = f"Coupon: {coupon.code}"
        order.original_total = total_amount
        order.total_amount = total_amount - discount
        Coupon.objects.filter(pk=coupon.pk).update(usage_count=coupon.usage_count + 1)

    if redeem_coins:
        available_coins = getattr(user, "loyalty_coins", 0)
        if available_coins > 0:
            redeemed = min(available_coins, int(order.total_amount))
            if redeemed > 0:
                order.coins_redeemed = redeemed
                order.total_amount = order.total_amount - Decimal(str(redeemed))
                user.loyalty_coins = available_coins - redeemed
                user.save(update_fields=["loyalty_coins"])

    order.save()

    # Create primary Payment record
    payment = Payment.objects.create(
        order=order,
        method=PaymentMethod.COD,
        status=PaymentStatus.PENDING,
        amount=order.total_amount,
    )
    order.payment_record = payment
    order.save(update_fields=["payment_record"])

    notify_new_order(order)

    from orders.views import _broadcast_order

    _broadcast_order(order, "new_order")

    return order


def confirm_order(order: Order, prep_time: int, staff_user) -> Order:
    """
    Confirms an order, sets estimated prep and delivery time, sends push notifications,
    schedules payment reminders if needed, and broadcasts the status update.
    """
    from orders.views import _broadcast_order

    order.status = "confirmed"
    order.confirmed_at = timezone.now()
    order.estimated_preparation_time = prep_time
    order.estimated_delivery_time = timezone.now() + timedelta(minutes=prep_time + 15)
    order.confirmed_by = staff_user
    order.save()

    notify_order_confirmed(order, prep_time)

    if order.payment_method == "online" and order.payment_status == "pending":
        _schedule_pending_online_payment_reminder(order.id)

    _broadcast_order(order)
    return order


def reject_order(order: Order, reason: str) -> Order:
    """
    Rejects an order, updates its status and reason, sends a rejection notification,
    and broadcasts the status update. Also initiates Cashfree refund if needed.
    """
    from orders.views import _broadcast_order

    order.status = "rejected"
    order.rejection_reason = reason
    order.cancellation_reason = reason
    order.rejected_at = timezone.now()

    if order.coins_redeemed > 0:
        customer = order.user
        customer.loyalty_coins = (
            getattr(customer, "loyalty_coins", 0) + order.coins_redeemed
        )
        customer.save(update_fields=["loyalty_coins"])

    # Initiate Cashfree Refund if paid online
    if order.payment_method == "online" and order.payment_status == "paid":
        from services.payments import initiate_cashfree_refund

        success = initiate_cashfree_refund(order, reason)
        if success:
            order.refund_status = "initiated"
            order.payment_status = "refunded"
        else:
            order.refund_status = "failed"
    else:
        order.refund_status = "not_applicable"

    order.save()

    notify_order_rejected(order, reason)
    _broadcast_order(order)
    return order


def apply_discount(order: Order, discount, reason: str, staff_user) -> Order:
    """
    Applies a discount to the order, updating totals and modified flag.
    """
    # Calculate true subtotal from items
    subtotal = sum(item.price * item.quantity for item in order.items.all())
    order.original_total = subtotal

    if discount > subtotal:
        raise ValueError("Discount cannot exceed the original order total.")

    order.discount_amount = discount
    order.discount_reason = reason
    order.total_amount = subtotal - discount
    order.is_modified_by_staff = True
    order.save(
        update_fields=[
            "discount_amount",
            "discount_reason",
            "total_amount",
            "original_total",
            "is_modified_by_staff",
            "updated_at",
        ]
    )

    logger.info(
        f"Discount applied: order_id={order.id}, "
        f"discount={discount}, reason='{reason}', "
        f"new_total={order.total_amount}, user_id={staff_user.id}"
    )
    return order


def acknowledge_changes(order: Order, accepted: bool) -> Order:
    """
    Handles customer acknowledgment of staff-modified orders.
    """
    if accepted:
        order.is_modified_by_staff = False
        order.save(update_fields=["is_modified_by_staff", "updated_at"])
        logger.info(f"Customer accepted modified order: order_id={order.id}")
    else:
        order.status = "rejected"
        order.rejection_reason = "Customer rejected the modified order."
        order.is_modified_by_staff = False
        order.save(
            update_fields=[
                "status",
                "rejection_reason",
                "is_modified_by_staff",
                "updated_at",
            ]
        )
        logger.info(f"Customer rejected modified order: order_id={order.id}")
    return order


def update_order_status(order: Order, new_status: str, staff_user) -> Order:
    """
    Validates user role permissions, applies delivery logic/coins reward, updates status,
    sends push notification, and broadcasts status update.
    """
    if hasattr(staff_user, "role") and staff_user.role == "delivery":
        if new_status not in ("out_for_delivery", "delivered"):
            raise PermissionError(
                "Delivery staff can only update status to Out For Delivery or Delivered."
            )
        if order.assigned_delivery_id != staff_user.id:
            raise PermissionError("You are not assigned to this order.")
    elif not (hasattr(staff_user, "role") and staff_user.role == "admin"):
        raise PermissionError("You do not have permission to perform this action.")

    if new_status == "delivered" and order.status != "delivered":
        from orders.views import _delivery_block_reason

        block_reason = _delivery_block_reason(order)
        if block_reason:
            raise ValueError(block_reason)

        from app_config.models import SiteConfig

        percentage = SiteConfig.get().loyalty_coins_percentage
        earned = int((order.total_amount * percentage) // 100)
        if earned > 0:
            customer = order.user
            customer.loyalty_coins = getattr(customer, "loyalty_coins", 0) + earned
            customer.save(update_fields=["loyalty_coins"])
            order.coins_earned = earned

    if new_status == "preparing":
        order.preparing_at = timezone.now()
    elif new_status == "out_for_delivery":
        order.out_for_delivery_at = timezone.now()
    elif new_status == "delivered":
        order.delivered_at = timezone.now()
    elif new_status == "cancelled":
        order.cancelled_at = timezone.now()
    elif new_status == "rejected":
        order.rejected_at = timezone.now()

    order.status = new_status
    order.save()

    from authentication.firebase import send_push

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
    }
    if new_status in _push_map:
        title, body = _push_map[new_status]
        try:
            send_push(
                order.user, title, body, {"order_id": str(order.id), "type": "order"}
            )
        except Exception as e:
            logger.warning(f"Could not send push notification: {e}")

    from orders.views import _broadcast_order

    _broadcast_order(order)
    return order


def assign_delivery_user(order: Order, delivery_user_id: int) -> Order:
    """
    Assigns order to a delivery user and triggers a notification.
    """
    try:
        delivery_user = User.objects.get(id=delivery_user_id, role="delivery")
    except User.DoesNotExist:
        raise ValidationError("Delivery user not found.")

    order.assigned_delivery = delivery_user
    order.save()

    from authentication.firebase import send_push

    try:
        send_push(
            delivery_user,
            "New Delivery Assigned 🛵",
            f"Order #{order.order_number} has been assigned to you.",
            {"order_id": str(order.id), "type": "order"},
        )
    except Exception as e:
        logger.warning(f"Could not send push notification: {e}")

    return order


def request_cancellation(order: Order, reason: str) -> Order:
    """
    Handles customer cancellation request.
    """
    if order.status in ["delivered", "cancelled", "rejected"]:
        raise ValidationError("Cannot request cancellation for this order.")

    order.cancellation_requested = True
    order.cancellation_reason = reason
    order.cancellation_requested_at = timezone.now()
    order.save()

    from orders.views import _broadcast_order

    _broadcast_order(order, "cancellation_requested")
    return order


def handle_cancellation_request(order: Order, action: str, reason: str) -> Order:
    """
    Approves or declines a cancellation request, triggering refund processes
    and loyalty coin restoration.
    """
    if action not in ["approve", "reject"]:
        raise ValidationError("Action must be either 'approve' or 'reject'.")

    from authentication.firebase import send_push

    if action == "approve":
        order.cancellation_approved = True
        order.status = "cancelled"
        order.cancelled_at = timezone.now()
        if reason:
            order.cancellation_reason = reason

        if order.coins_redeemed > 0:
            customer = order.user
            customer.loyalty_coins = (
                getattr(customer, "loyalty_coins", 0) + order.coins_redeemed
            )
            customer.save(update_fields=["loyalty_coins"])

        # Initiate Cashfree Refund if paid online
        if order.payment_method == "online" and order.payment_status == "paid":
            from services.payments import initiate_cashfree_refund

            success = initiate_cashfree_refund(
                order, reason or "Customer Cancellation Request Approved"
            )
            if success:
                order.refund_status = "initiated"
                order.payment_status = "refunded"
            else:
                order.refund_status = "failed"
        else:
            order.refund_status = "not_applicable"

        try:
            send_push(
                order.user,
                "Order Cancelled 🚫",
                f"Your cancellation request for order #{order.order_number} has been approved.",
                {"order_id": str(order.id), "type": "order"},
            )
        except Exception as e:
            logger.warning(f"Could not send push notification: {e}")
    else:
        order.cancellation_approved = False
        order.cancellation_requested = (
            False  # Reset so they can request again if needed
        )
        try:
            send_push(
                order.user,
                "Cancellation Request Declined ⚠️",
                f"Your cancellation request for order #{order.order_number} was declined.",
                {"order_id": str(order.id), "type": "order"},
            )
        except Exception as e:
            logger.warning(f"Could not send push notification: {e}")

    order.save()
    from orders.views import _broadcast_order

    _broadcast_order(order)
    return order


def admin_cancel_order(order: Order, reason: str) -> Order:
    """
    Directly cancels an order from admin panel, issuing refund and loyalty coins restoration.
    """
    order.status = "cancelled"
    order.cancellation_reason = reason
    order.cancellation_approved = True
    order.cancelled_at = timezone.now()

    if order.coins_redeemed > 0:
        customer = order.user
        customer.loyalty_coins = (
            getattr(customer, "loyalty_coins", 0) + order.coins_redeemed
        )
        customer.save(update_fields=["loyalty_coins"])

    # Initiate Cashfree Refund if paid online
    if order.payment_method == "online" and order.payment_status == "paid":
        from services.payments import initiate_cashfree_refund

        success = initiate_cashfree_refund(order, reason)
        if success:
            order.refund_status = "initiated"
            order.payment_status = "refunded"
        else:
            order.refund_status = "failed"
    else:
        order.refund_status = "not_applicable"

    order.save()
    from orders.views import _broadcast_order

    _broadcast_order(order)

    from authentication.firebase import send_push

    try:
        send_push(
            order.user,
            "Order Cancelled 🚫",
            f"Your order #{order.order_number} has been cancelled by the kitchen: {reason}",
            {"order_id": str(order.id), "type": "order"},
        )
    except Exception as e:
        logger.warning(f"Could not send push notification: {e}")

    return order


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


def admin_create_order(
    phone_number: str,
    customer_name: str,
    delivery_type: str,
    address_text: str,
    address_id: int,
    house: str,
    street: str,
    landmark: str,
    city: str,
    pincode: str,
    items: list,
    payment_method: str = "cod",
    coupon_code: str = "",
    delivery_notes: str = "",
) -> Order:
    """
    Admin manually places an order for a customer by their phone number.
    """
    from django.db.models import Q
    from accounts.models import User, Address

    if not phone_number:
        raise ValidationError("Phone number is required.")

    if not items:
        raise ValidationError("At least one item is required.")

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
        # Update name if provided
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
            raise ValidationError("Invalid or expired coupon code.")

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
            raise ValidationError(f"Product with ID {product_id} not found.")

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
            raise ValidationError("Coupon is not yet valid.")
        if coupon.valid_until and now > coupon.valid_until:
            order.delete()
            raise ValidationError("Coupon has expired.")
        if coupon.usage_limit and coupon.usage_count >= coupon.usage_limit:
            order.delete()
            raise ValidationError("Coupon usage limit reached.")
        if total_amount < coupon.min_order_amount:
            order.delete()
            raise ValidationError(
                f"Minimum order amount for this coupon is ₹{coupon.min_order_amount}."
            )

        discount = coupon.compute_discount(total_amount)
        order.discount_amount = discount
        order.discount_reason = f"Coupon: {coupon.code}"
        order.original_total = total_amount
        order.total_amount = total_amount - discount
        Coupon.objects.filter(pk=coupon.pk).update(usage_count=coupon.usage_count + 1)

    order.save()

    # Send push notification to user (if FCM token is available)
    from authentication.firebase import send_push

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
    from orders.views import _broadcast_order

    _broadcast_order(order, "new_order")

    return order


def edit_order_items(order: Order, items_data: list, staff_user) -> Order:
    """
    Chef or admin edits order items before confirmation.
    Recalculates coupon discount and totals.
    """
    if order.status != "pending_confirmation":
        raise ValidationError("Items can only be edited before confirmation.")

    if not items_data:
        raise ValidationError("At least one item is required.")

    # Snapshot original total before any modification if not already set.
    if order.original_total is None:
        order.original_total = order.total_amount

    # Delete existing items and recalculate.
    order.items.all().delete()
    total_amount = Decimal("0.00")

    for item in items_data:
        try:
            product = Product.objects.get(id=item["product_id"])
        except Product.DoesNotExist:
            raise ValidationError(f"Product {item['product_id']} not found.")

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
        f"new_total={total_amount}, user_id={staff_user.id}"
    )

    from orders.views import _broadcast_order

    _broadcast_order(order)

    return order
