from django.db import models
from accounts.models import User


class Notification(models.Model):
    """In-app notifications for users (global announcements or user-specific order updates)."""

    user = models.ForeignKey(
        User,
        null=True,
        blank=True,
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    title = models.CharField(max_length=255)
    body = models.TextField()
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "app_config_notification"
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.title} - {self.user.phone_number if self.user else 'All'}"
