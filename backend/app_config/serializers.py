from rest_framework import serializers
from .models import Banner, SiteConfig, Notification


class SiteConfigSerializer(serializers.ModelSerializer):
    class Meta:
        model = SiteConfig
        fields = [
            "announcement",
            "is_store_open",
            "store_open_time",
            "store_close_time",
            "store_closed_msg",
            "show_ratings",
            "scheduled_close_start",
            "scheduled_close_end",
            "scheduled_closed_msg",
            "merchant_upi_id",
            "loyalty_coins_percentage",
            "kitchen_name",
            "kitchen_latitude",
            "kitchen_longitude",
        ]

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        from django.utils import timezone

        now = timezone.now()
        if instance.scheduled_close_start and instance.scheduled_close_end:
            if instance.scheduled_close_start <= now <= instance.scheduled_close_end:
                ret["is_store_open"] = False
                ret["store_closed_msg"] = (
                    instance.scheduled_closed_msg or instance.store_closed_msg
                )
        return ret


class BannerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Banner
        fields = [
            "id",
            "image_url",
            "title",
            "subtitle",
            "link_action",
            "order",
            "is_active",
        ]

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        if ret.get("image_url") and not ret["image_url"].startswith("http"):
            request = self.context.get("request")
            if request is not None:
                ret["image_url"] = request.build_absolute_uri(ret["image_url"])
            else:
                from django.conf import settings

                domain = getattr(settings, "SITE_DOMAIN", "https://api.hdkfoods.in")
                ret["image_url"] = (
                    domain.rstrip("/") + "/" + ret["image_url"].lstrip("/")
                )
        return ret


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ["id", "title", "body", "is_read", "created_at"]
