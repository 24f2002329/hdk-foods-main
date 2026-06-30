from rest_framework import serializers
from django.contrib.auth.hashers import make_password
from .models import Address, User


class UserSerializer(serializers.ModelSerializer):

    class Meta:
        model = User
        fields = ["id", "phone_number", "name", "role", "loyalty_coins"]
        read_only_fields = ["id", "phone_number", "role", "loyalty_coins"]

    def validate_name(self, value):
        from authentication.utils import sanitize_text
        return sanitize_text(value)


class DeliveryStaffSerializer(serializers.ModelSerializer):
    """Delivery user list — includes the default flag."""

    class Meta:
        model = User
        fields = ["id", "phone_number", "name", "is_default_delivery"]
        read_only_fields = ["id", "phone_number", "name"]


class CreateDeliveryStaffSerializer(serializers.ModelSerializer):
    """Admin creates a new delivery staff account."""

    password = serializers.CharField(write_only=True, min_length=6)

    class Meta:
        model = User
        fields = ["phone_number", "name", "password"]

    def create(self, validated_data):
        return User.objects.create_user(
            phone_number=validated_data["phone_number"],
            password=validated_data["password"],
            name=validated_data.get("name", ""),
            role="delivery",
            is_phone_verified=True,
        )


class AddressSerializer(
    serializers.ModelSerializer
):

    class Meta:
        model = Address

        fields = [
            "id",
            "label",
            "house",
            "street",
            "landmark",
            "city",
            "pincode",
            "latitude",
            "longitude",
            "is_default",
        ]

        read_only_fields = [
            "id"
        ]

    def validate(self, data):
        from authentication.utils import sanitize_text
        for field in ["label", "house", "street", "landmark", "city", "pincode"]:
            if field in data and isinstance(data[field], str):
                data[field] = sanitize_text(data[field])
        return data

