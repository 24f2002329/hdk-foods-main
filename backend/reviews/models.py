from django.db import models
from accounts.models import User
from products.models import Product


class OrderReview(models.Model):
    """One review per delivered order, submitted by the customer."""

    order = models.OneToOneField(
        "orders.Order", on_delete=models.CASCADE, related_name="review"
    )
    customer = models.ForeignKey(User, on_delete=models.CASCADE, related_name="reviews")
    rating = models.PositiveSmallIntegerField()  # 1-5
    comment = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "orders_orderreview"

    def __str__(self):
        return f"Review for {self.order.order_number} — {self.rating}★"


class ProductReview(models.Model):
    product = models.ForeignKey(
        Product, on_delete=models.CASCADE, related_name="reviews"
    )
    customer = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="product_reviews"
    )
    order = models.ForeignKey(
        "orders.Order", on_delete=models.CASCADE, related_name="product_reviews"
    )
    rating = models.PositiveSmallIntegerField()  # 1-5
    comment = models.TextField(blank=True, default="")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "orders_productreview"
        unique_together = ("order", "product")

    def __str__(self):
        return f"Review for {self.product.name} in {self.order.order_number} — {self.rating}★"
