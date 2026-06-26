from rest_framework import serializers
from .models import Category, Product


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = "__all__"

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        if ret.get("image") and not ret["image"].startswith("http"):
            request = self.context.get("request")
            if request is not None:
                ret["image"] = request.build_absolute_uri(ret["image"])
            else:
                from django.conf import settings
                domain = getattr(settings, "SITE_DOMAIN", "https://api.hdkfoods.in")
                ret["image"] = domain.rstrip("/") + "/" + ret["image"].lstrip("/")
        return ret


class ProductSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)

    class Meta:
        model = Product
        fields = "__all__"

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        if ret.get("image") and not ret["image"].startswith("http"):
            request = self.context.get("request")
            if request is not None:
                ret["image"] = request.build_absolute_uri(ret["image"])
            else:
                from django.conf import settings
                domain = getattr(settings, "SITE_DOMAIN", "https://api.hdkfoods.in")
                ret["image"] = domain.rstrip("/") + "/" + ret["image"].lstrip("/")
        return ret


class ProductWriteSerializer(serializers.ModelSerializer):
    """Used for create/update — accepts category as a PK."""
    class Meta:
        model = Product
        fields = [
            "id", "category", "name", "description",
            "price", "image", "is_available", "is_featured",
            "is_addon", "preparation_time", "rating",
            "promo_tag", "strike_price",
        ]

    def to_representation(self, instance):
        ret = super().to_representation(instance)
        if ret.get("image") and not ret["image"].startswith("http"):
            request = self.context.get("request")
            if request is not None:
                ret["image"] = request.build_absolute_uri(ret["image"])
            else:
                from django.conf import settings
                domain = getattr(settings, "SITE_DOMAIN", "https://api.hdkfoods.in")
                ret["image"] = domain.rstrip("/") + "/" + ret["image"].lstrip("/")
        return ret