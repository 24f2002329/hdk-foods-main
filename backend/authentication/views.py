from django.shortcuts import render

# Create your views here.
from django.contrib.auth import authenticate

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from rest_framework_simplejwt.tokens import RefreshToken

from .serializers import (
    StaffLoginSerializer,
    UserSerializer,
    VerifyOTPSerializer
)

from rest_framework.permissions import (
    IsAuthenticated
)

from accounts.models import User

import authentication.firebase
from firebase_admin import auth


class StaffLoginView(APIView):

    def post(self, request):

        serializer = (
            StaffLoginSerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        phone_number = serializer.validated_data[
            "phone_number"
        ]

        password = serializer.validated_data[
            "password"
        ]

        try:

            user = User.objects.get(
                phone_number=phone_number
            )

        except User.DoesNotExist:

            return Response(
                {
                    "error": "User not found"
                },
                status=400
            )

        if not user.check_password(
            password
        ):
            return Response(
                {
                    "error": "Invalid password"
                },
                status=400
            )

        refresh = RefreshToken.for_user(
            user
        )

        return Response(
            {
                "access": str(
                    refresh.access_token
                ),

                "refresh": str(
                    refresh
                ),

                "role": user.role
            }
        )



class MeView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    def get(self, request):

        return Response(
            UserSerializer(
                request.user
            ).data
        )
    



class VerifyOTPView(APIView):

    def post(
        self,
        request
    ):

        serializer = (
            VerifyOTPSerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        firebase_token = (
            serializer.validated_data[
                "firebase_token"
            ]
        )

        decoded_token = (
            auth.verify_id_token(
                firebase_token
            )
        )

        phone_number = (
            decoded_token[
                "phone_number"
            ]
        )

        user, created = User.objects.get_or_create(
            phone_number=phone_number,
            defaults={
                "name": "",
                "role": "customer",
                "is_phone_verified": True
            }
        )

        if not user.is_phone_verified:
            user.is_phone_verified = True
            user.save(update_fields=["is_phone_verified"])


        refresh = (
            RefreshToken.for_user(
                user
            )
        )

        return Response(
            {
                "access":
                    str(
                        refresh.access_token
                    ),

                "refresh":
                    str(
                        refresh
                    ),

                "new_user":
                    created,

                "role":
                    user.role
            }
        )