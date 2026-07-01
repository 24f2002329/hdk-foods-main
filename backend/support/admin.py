from django.contrib import admin
from .models import OrderMessage

@admin.register(OrderMessage)
class OrderMessageAdmin(admin.ModelAdmin):
    list_display = ("id", "order", "sender", "is_admin", "created_at")
    list_filter = ("is_admin", "created_at")
    search_fields = ("order__order_number", "message")
