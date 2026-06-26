from rest_framework import serializers
from .models import Category, Product, ModifierGroup, ModifierOption


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
    modifier_groups = serializers.SerializerMethodField()

    class Meta:
        model = Product
        fields = "__all__"

    def get_modifier_groups(self, obj):
        groups = obj.modifier_groups.filter(visibility=True).order_by("display_order")
        overrides = {
            override.modifier_option_id: override.extra_price
            for override in obj.price_overrides.all()
        }
        
        serialized_groups = []
        for group in groups:
            group_data = {
                "id": group.id,
                "name": group.name,
                "selection_type": group.selection_type,
                "required": group.required,
                "min_selection": group.min_selection,
                "max_selection": group.max_selection,
                "display_order": group.display_order,
                "description": group.description,
                "options": []
            }
            options = group.options.filter(is_available=True).order_by("sort_order")
            for option in options:
                price = overrides.get(option.id, option.extra_price)
                group_data["options"].append({
                    "id": option.id,
                    "name": option.name,
                    "extra_price": float(price),
                    "is_available": option.is_available,
                    "image": option.image or "",
                    "sort_order": option.sort_order
                })
            serialized_groups.append(group_data)
        return serialized_groups

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
            "promo_tag", "strike_price", "modifier_groups",
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


class ModifierOptionWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = ModifierOption
        fields = "__all__"


class ModifierGroupWriteSerializer(serializers.ModelSerializer):
    options = ModifierOptionWriteSerializer(many=True, read_only=True)

    class Meta:
        model = ModifierGroup
        fields = "__all__"