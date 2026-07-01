from django.contrib import admin
from .models import Notification, NotificationLog


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ("title", "user", "priority", "is_read", "created_at")
    list_filter = ("priority", "is_read", "created_at")
    search_fields = ("title", "body", "user__phone_number")


@admin.register(NotificationLog)
class NotificationLogAdmin(admin.ModelAdmin):
    list_display = (
        "title",
        "user",
        "target_role",
        "status",
        "priority",
        "attempts",
        "created_at",
        "sent_at",
    )
    list_filter = ("status", "priority", "target_role", "created_at", "sent_at")
    search_fields = (
        "title",
        "body",
        "user__phone_number",
        "token",
        "fcm_message_id",
        "error",
    )
    readonly_fields = ("created_at", "updated_at", "sent_at")
