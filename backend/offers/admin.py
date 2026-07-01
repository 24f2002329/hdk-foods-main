from django.contrib import admin
from .models import Coupon

@admin.register(Coupon)
class CouponAdmin(admin.ModelAdmin):
    list_display = ("code", "discount_type", "discount_value", "min_order_amount", "max_discount_amount", "is_active", "valid_until", "usage_count")
    list_editable = ("is_active",)
    list_filter = ("discount_type", "is_active")
    search_fields = ("code",)
