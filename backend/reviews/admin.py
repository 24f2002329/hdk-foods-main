from django.contrib import admin
from .models import OrderReview, ProductReview

@admin.register(OrderReview)
class OrderReviewAdmin(admin.ModelAdmin):
    list_display = ("order", "customer", "rating", "created_at")
    list_filter = ("rating", "created_at")
    search_fields = ("order__order_number", "customer__phone_number", "comment")

@admin.register(ProductReview)
class ProductReviewAdmin(admin.ModelAdmin):
    list_display = ("product", "customer", "order", "rating", "created_at")
    list_filter = ("rating", "created_at")
    search_fields = ("product__name", "customer__phone_number", "order__order_number", "comment")
