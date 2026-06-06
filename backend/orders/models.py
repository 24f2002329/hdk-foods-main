from django.db import models
from accounts.models import User, Address
from products.models import Product


class Order(models.Model):

    STATUS_CHOICES = [
        ("pending_confirmation", "Pending Confirmation"),
        ("confirmed", "Confirmed"),
        ("preparing", "Preparing"),
        ("ready_for_pickup", "Ready For Pickup"),
        ("out_for_delivery", "Out For Delivery"),
        ("delivered", "Delivered"),
        ("cancelled", "Cancelled"),
        ("rejected", "Rejected"),
    ]

    order_number = models.CharField(
        max_length=20,
        unique=True,
        blank=True
    )

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE
    )

    address = models.ForeignKey(
        Address,
        on_delete=models.CASCADE
    )

    total_amount = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending_confirmation"
    )

    payment_method = models.CharField(
        max_length=20,
        default="cod"
    )

    payment_status = models.CharField(
        max_length=20,
        default="pending"
    )

    payment_id = models.CharField(
        max_length=255,
        blank=True
    )

    razorpay_order_id = models.CharField(
        max_length=255,
        blank=True
    )

    delivery_notes = models.TextField(
        blank=True
    )

    estimated_preparation_time = models.PositiveIntegerField(
        null=True,
        blank=True
    )

    estimated_delivery_time = models.DateTimeField(
        null=True,
        blank=True
    )

    confirmed_at = models.DateTimeField(
        null=True,
        blank=True
    )

    rejection_reason = models.TextField(
        blank=True
    )

    confirmed_by = models.ForeignKey(
        "accounts.User",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="confirmed_orders"
    )

    assigned_delivery = models.ForeignKey(
        "accounts.User",
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name="assigned_deliveries"
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    updated_at = models.DateTimeField(
        auto_now=True
    )

    def save(self, *args, **kwargs):

        if not self.order_number:
            last_order = Order.objects.order_by(
                "-id"
            ).first()

            next_id = 1001

            if last_order:
                next_id = last_order.id + 1001

            self.order_number = (
                f"HDK{next_id}"
            )

        super().save(*args, **kwargs)

    def __str__(self):
        return self.order_number
    

class OrderItem(models.Model):

    order = models.ForeignKey(
        Order,
        related_name="items",
        on_delete=models.CASCADE
    )

    product = models.ForeignKey(
        Product,
        on_delete=models.CASCADE
    )

    quantity = models.PositiveIntegerField()

    price = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    def __str__(self):
        return self.product.name