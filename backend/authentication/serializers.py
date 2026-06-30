from rest_framework import serializers
from accounts.models import User


class StaffLoginSerializer(serializers.Serializer):
    phone_number = serializers.CharField()

    password = serializers.CharField()


class UserSerializer(serializers.ModelSerializer):

    class Meta:
        model = User

        fields = [
            "id",
            "name",
            "phone_number",
            "role"
        ]


class VerifyOTPSerializer(serializers.Serializer):

    firebase_token = (
        serializers.CharField()
    )


class SendSMSSerializer(serializers.Serializer):
    phone_number = serializers.CharField()