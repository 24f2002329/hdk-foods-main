from django.contrib import admin
from .models import Order, OrderItem, Coupon

# Register your models here.

@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):

    list_display = (
        "id",
        "user",
        "status",
        "total_amount",
        "payment_status",
        "created_at"
    )

    list_filter = (
        "status",
        "payment_status"
    )


admin.site.register(OrderItem)

@admin.register(Coupon)
class CouponAdmin(admin.ModelAdmin):
    list_display = ("code", "discount_type", "discount_value", "min_order_amount", "max_discount_amount", "is_active", "valid_until", "usage_count")
    list_editable = ("is_active",)
    list_filter = ("discount_type", "is_active")
    search_fields = ("code",)