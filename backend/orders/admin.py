from django.contrib import admin
from .models import Order, OrderItem

# Register your models here.


@admin.register(Order)
class OrderAdmin(admin.ModelAdmin):

    list_display = (
        "id",
        "user",
        "status",
        "total_amount",
        "payment_status",
        "created_at",
    )

    list_filter = ("status", "payment_status")


admin.site.register(OrderItem)
