from django.contrib import admin
from .models import Payment, PaymentAttempt


class PaymentAttemptInline(admin.TabularInline):
    model = PaymentAttempt
    extra = 0
    readonly_fields = (
        "gateway",
        "gateway_order_id",
        "payment_session_id",
        "gateway_payment_id",
        "status",
        "amount",
        "created_at",
    )
    can_delete = False


@admin.register(Payment)
class PaymentAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "order",
        "method",
        "status",
        "amount",
        "gateway_payment_id",
        "created_at",
    )
    list_filter = ("method", "status")
    search_fields = ("order__order_number", "gateway_payment_id")
    readonly_fields = ("created_at", "updated_at")
    inlines = [PaymentAttemptInline]


@admin.register(PaymentAttempt)
class PaymentAttemptAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "payment",
        "gateway",
        "gateway_order_id",
        "status",
        "amount",
        "created_at",
    )
    list_filter = ("gateway", "status")
    search_fields = ("gateway_order_id", "gateway_payment_id")
    readonly_fields = ("created_at", "updated_at")
