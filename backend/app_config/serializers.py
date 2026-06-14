from rest_framework import serializers
from .models import Banner, SiteConfig


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
        ]


class BannerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Banner
        fields = ["id", "image_url", "title", "subtitle", "link_action", "order", "is_active"]
