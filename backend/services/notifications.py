from authentication.firebase import send_push, send_push_to_role, send_push_to_all


def notify_new_order(order):
    """Notify administrators about a new order awaiting review."""
    send_push_to_role(
        "admin",
        "New Order 🛍️",
        f"Order #{order.order_number} is waiting for review.",
        {"order_id": str(order.id)},
    )


def notify_order_confirmed(order, prep_time: int):
    """Notify the customer that their order has been confirmed."""
    send_push(
        order.user,
        "Order Confirmed ✅",
        f"Your order #{order.order_number} is confirmed! Ready in ~{prep_time} mins.",
        {"order_id": str(order.id), "type": "order"},
    )


def notify_payment_reminder(order):
    """Notify the customer to complete payment for a pending online order."""
    send_push(
        order.user,
        "Complete payment",
        f"Your payment for order #{order.order_number} is still pending. Tap to complete it.",
        {"order_id": str(order.id), "type": "payment_pending"},
    )


def notify_order_rejected(order, reason: str):
    """Notify the customer that their order was rejected."""
    send_push(
        order.user,
        "Order Rejected ❌",
        f"Your order #{order.order_number} was rejected. Reason: {reason}",
        {"order_id": str(order.id), "type": "order"},
    )
