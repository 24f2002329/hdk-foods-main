"""
payments/models.py
──────────────────────────────────────────────────────────────────────────────
Dedicated payment tracking, decoupled from the Order model.

Structure
─────────
Order
 └── Payment            (one per order, created when a payment method is chosen)
      └── PaymentAttempt (one per gateway call; supports retries)

Benefits
────────
• Retries  – each failed attempt is preserved; a new attempt gets a fresh ID.
• Refunds  – attach refund metadata without polluting Order.
• Auditing – full, immutable ledger of every gateway interaction.
• Multi-gateway – gateway field makes it trivial to add Razorpay / Stripe later.
"""

from django.db import models
from django.utils import timezone


class PaymentMethod(models.TextChoices):
    COD = "cod", "Cash on Delivery"
    ONLINE = "online", "Online (Cashfree)"
    UPI = "upi", "UPI (Driver-verified)"


class PaymentStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    PAID = "paid", "Paid"
    FAILED = "failed", "Failed"
    REFUNDED = "refunded", "Refunded"
    PARTIAL_REFUND = "partial_refund", "Partially Refunded"


class Payment(models.Model):
    """
    The canonical payment record for a single order.

    Created the moment the customer (or driver) selects a payment method.
    Updated as the payment lifecycle progresses.
    """

    # Avoid circular import — Order references Payment via FK, Payment
    # references Order via a string to keep the dependency one-directional.
    order = models.OneToOneField(
        "orders.Order",
        on_delete=models.CASCADE,
        related_name="payment",
    )

    method = models.CharField(
        max_length=20,
        choices=PaymentMethod.choices,
        default=PaymentMethod.COD,
    )

    status = models.CharField(
        max_length=20,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING,
    )

    # Total amount that was (or should be) collected, in INR.
    amount = models.DecimalField(max_digits=10, decimal_places=2)

    # Filled by the gateway or driver-verify flow on success.
    gateway_payment_id = models.CharField(max_length=255, blank=True)

    # Refund tracking
    refund_status = models.CharField(max_length=50, blank=True, default="")
    refunded_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    refunded_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"Payment[{self.method}|{self.status}] for Order {self.order_id}"

    # ── convenience helpers ──────────────────────────────────────────────────

    @property
    def latest_attempt(self):
        return self.attempts.order_by("-created_at").first()

    def mark_paid(self, gateway_payment_id: str = "") -> None:
        self.status = PaymentStatus.PAID
        self.gateway_payment_id = gateway_payment_id
        self.save(update_fields=["status", "gateway_payment_id", "updated_at"])

    def mark_failed(self) -> None:
        self.status = PaymentStatus.FAILED
        self.save(update_fields=["status", "updated_at"])


class Gateway(models.TextChoices):
    CASHFREE = "cashfree", "Cashfree"
    RAZORPAY = "razorpay", "Razorpay (legacy)"
    UPI_MANUAL = "upi_manual", "UPI (manual driver verification)"
    NONE = "none", "None (COD)"


class PaymentAttempt(models.Model):
    """
    One row per gateway call.

    Why: Cashfree requires a fresh order_id for every retry (it returns
    ``order_already_exists`` if the same id is reused after a failure).
    Storing each attempt here gives us a full, auditable history of every
    checkout initiated against a gateway.
    """

    payment = models.ForeignKey(
        Payment,
        on_delete=models.CASCADE,
        related_name="attempts",
    )

    gateway = models.CharField(
        max_length=20,
        choices=Gateway.choices,
        default=Gateway.CASHFREE,
    )

    # Gateway-side identifiers
    gateway_order_id = models.CharField(max_length=64, blank=True)
    payment_session_id = models.CharField(max_length=255, blank=True)
    gateway_payment_id = models.CharField(max_length=255, blank=True)

    status = models.CharField(
        max_length=20,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING,
    )

    amount = models.DecimalField(max_digits=10, decimal_places=2)

    # Raw response snapshot for debugging / support queries
    gateway_response = models.JSONField(null=True, blank=True)

    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return (
            f"Attempt[{self.gateway}|{self.status}] " f"for Payment {self.payment_id}"
        )
