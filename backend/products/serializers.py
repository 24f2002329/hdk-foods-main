from rest_framework import serializers
from .models import Category, Product


class CategorySerializer(serializers.ModelSerializer):
    class Meta:
        model = Category
        fields = "__all__"


class ProductSerializer(serializers.ModelSerializer):
    category = CategorySerializer(read_only=True)

    class Meta:
        model = Product
        fields = "__all__"


class ProductWriteSerializer(serializers.ModelSerializer):
    """Used for create/update — accepts category as a PK."""
    class Meta:
        model = Product
        fields = [
            "id", "category", "name", "description",
            "price", "image", "is_available", "is_featured",
            "is_addon", "preparation_time",
        ]