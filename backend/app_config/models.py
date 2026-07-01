from datetime import time
from django.db import models


class SiteConfig(models.Model):
    """Singleton — always fetched as pk=1. Created with defaults on first GET."""

    # Hero / promotional
    announcement = models.CharField(max_length=255, blank=True, default="")

    # Store hours
    is_store_open = models.BooleanField(default=True)
    store_open_time = models.TimeField(default=time(8, 0))
    store_close_time = models.TimeField(default=time(22, 0))
    store_closed_msg = models.CharField(
        max_length=255, blank=True, default="We're closed right now. See you soon!"
    )

    # Scheduled closures
    scheduled_close_start = models.DateTimeField(
        null=True, blank=True, help_text="Start date & time of the scheduled closure"
    )
    scheduled_close_end = models.DateTimeField(
        null=True, blank=True, help_text="End date & time of the scheduled closure"
    )
    scheduled_closed_msg = models.CharField(
        max_length=255,
        blank=True,
        default="We are closed for a scheduled holiday/maintenance. See you soon!",
    )

    # Ratings
    show_ratings = models.BooleanField(default=True)

    # Direct UPI
    merchant_upi_id = models.CharField(
        max_length=255,
        default="hdkfoods@axisbank",
        help_text="Merchant UPI ID to receive direct payments",
    )

    # Loyalty Coins
    loyalty_coins_percentage = models.PositiveIntegerField(
        default=10,
        help_text="Loyalty coins percentage of order value (e.g. 5 means 5%)",
    )

    # Kitchen / Restaurant location (used on map across all apps)
    kitchen_name = models.CharField(
        max_length=100,
        default="HDK Foods Kitchen",
        help_text="Display name for the kitchen on maps",
    )
    kitchen_latitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        default="25.9233000",
        help_text="Kitchen GPS latitude",
    )
    kitchen_longitude = models.DecimalField(
        max_digits=10,
        decimal_places=7,
        default="73.6646000",
        help_text="Kitchen GPS longitude",
    )

    class Meta:
        verbose_name = "Site Configuration"

    def __str__(self):
        return "Site Configuration"

    def is_currently_open(self):
        if not self.is_store_open:
            return False

        from django.utils import timezone

        now = timezone.now()
        if self.scheduled_close_start and self.scheduled_close_end:
            if self.scheduled_close_start <= now <= self.scheduled_close_end:
                return False

        try:
            import zoneinfo

            tz = zoneinfo.ZoneInfo("Asia/Kolkata")
        except ImportError:
            import pytz

            tz = pytz.timezone("Asia/Kolkata")

        now_local = timezone.now().astimezone(tz).time()

        if self.store_open_time <= self.store_close_time:
            return self.store_open_time <= now_local <= self.store_close_time
        else:
            return (
                now_local >= self.store_open_time or now_local <= self.store_close_time
            )

    @classmethod
    def get(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj


class Banner(models.Model):
    """Rotating hero banners shown on the customer home screen."""

    image_url = models.URLField(blank=True, default="")
    title = models.CharField(max_length=100, blank=True, default="")
    subtitle = models.CharField(max_length=200, blank=True, default="")
    link_action = models.CharField(
        max_length=50,
        blank=True,
        default="",
        help_text="e.g. 'menu', 'orders' — navigates customer to that section",
    )
    order = models.PositiveIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        ordering = ["order"]

    def __str__(self):
        return self.title or self.image_url


# Import moved models to maintain namespace backward-compatibility
from notifications.models import Notification
