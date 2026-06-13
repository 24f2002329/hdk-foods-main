from rest_framework import serializers
from .models import Address, User


class UserSerializer(serializers.ModelSerializer):

    class Meta:
        model = User
        fields = ["id", "phone_number", "name", "role"]
        read_only_fields = ["id", "phone_number", "role"]


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
