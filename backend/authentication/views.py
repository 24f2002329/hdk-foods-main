import time
from django.shortcuts import render
from django.contrib.auth import authenticate
from django.conf import settings
from django.core.cache import cache

from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated

from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError

from .serializers import (
    StaffLoginSerializer,
    UserSerializer,
    VerifyOTPSerializer,
    SendSMSSerializer
)

from accounts.models import User
import authentication.firebase
from firebase_admin import auth


def get_client_ip(request):
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0].strip()
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


class SendSMSView(APIView):
    """
    Rate-limited SMS send endpoint.
    Limits:
    - Max 3 requests per phone number per 15 minutes.
    - Max 10 requests per IP address per hour.
    """
    def post(self, request):
        serializer = SendSMSSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        phone_number = serializer.validated_data['phone_number'].strip()
        
        ip = get_client_ip(request)
        now = time.time()
        
        # 1. IP rate limiting (max 10 requests per IP per hour)
        ip_cache_key = f"sms_limit_ip_{ip}"
        ip_timestamps = cache.get(ip_cache_key, [])
        ip_timestamps = [t for t in ip_timestamps if now - t < 3600]
        
        if len(ip_timestamps) >= 10:
            return Response(
                {"detail": "Too many requests from this IP. Maximum 10 requests per hour."},
                status=status.HTTP_429_TOO_MANY_REQUESTS
            )
            
        # 2. Phone rate limiting (max 3 requests per phone number per 15 minutes)
        phone_cache_key = f"sms_limit_phone_{phone_number}"
        phone_timestamps = cache.get(phone_cache_key, [])
        phone_timestamps = [t for t in phone_timestamps if now - t < 900]
        
        if len(phone_timestamps) >= 3:
            return Response(
                {"detail": "Too many requests for this phone number. Maximum 3 requests per 15 minutes."},
                status=status.HTTP_429_TOO_MANY_REQUESTS
            )
            
        # Add timestamps and store in cache
        ip_timestamps.append(now)
        phone_timestamps.append(now)
        
        cache.set(ip_cache_key, ip_timestamps, 3600)
        cache.set(phone_cache_key, phone_timestamps, 900)
        
        return Response({
            "status": "OTP sent",
            "detail": "SMS verification request registered successfully."
        })


class StaffLoginView(APIView):
    def post(self, request):
        serializer = StaffLoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        phone_number = serializer.validated_data["phone_number"]
        password = serializer.validated_data["password"]

        try:
            user = User.objects.get(phone_number=phone_number)
        except User.DoesNotExist:
            return Response(
                {"error": "User not found"},
                status=400
            )

        if not user.check_password(password):
            return Response(
                {"error": "Invalid password"},
                status=400
            )

        refresh = RefreshToken.for_user(user)

        response = Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "role": user.role
            }
        )

        # Set secure HTTP-only cookie for web clients
        response.set_cookie(
            key="refresh_token",
            value=str(refresh),
            httponly=True,
            secure=not settings.DEBUG,
            samesite="Lax",
            max_age=30 * 24 * 60 * 60,
        )

        return response


class MeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(
            UserSerializer(request.user).data
        )


class VerifyOTPView(APIView):
    def post(self, request):
        serializer = VerifyOTPSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        firebase_token = serializer.validated_data["firebase_token"]
        decoded_token = auth.verify_id_token(firebase_token)
        phone_number = decoded_token["phone_number"]

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

        refresh = RefreshToken.for_user(user)

        response = Response(
            {
                "access": str(refresh.access_token),
                "refresh": str(refresh),
                "new_user": created,
                "role": user.role
            }
        )

        # Set secure HTTP-only cookie for web clients
        response.set_cookie(
            key="refresh_token",
            value=str(refresh),
            httponly=True,
            secure=not settings.DEBUG,
            samesite="Lax",
            max_age=30 * 24 * 60 * 60,
        )

        return response


class CookieTokenRefreshView(TokenRefreshView):
    """
    Custom TokenRefreshView that checks HTTP-only cookies if no refresh
    token is passed in the request body. Also sets rotated refresh token
    back in cookie.
    """
    def post(self, request, *args, **kwargs):
        raw_refresh = request.data.get("refresh")
        if not raw_refresh:
            raw_refresh = request.COOKIES.get("refresh_token")

        if not raw_refresh:
            return Response(
                {"detail": "Refresh token not provided."},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = self.get_serializer(data={"refresh": raw_refresh})
        try:
            serializer.is_valid(raise_exception=True)
        except TokenError as e:
            raise InvalidToken(e.args[0])

        res_data = serializer.validated_data
        new_refresh = res_data.get("refresh")

        response = Response({
            "access": res_data.get("access"),
        })

        if new_refresh:
            response.set_cookie(
                key="refresh_token",
                value=new_refresh,
                httponly=True,
                secure=not settings.DEBUG,
                samesite="Lax",
                max_age=30 * 24 * 60 * 60,
            )
        elif raw_refresh:
            # If not rotated but still valid, refresh the cookie lifetime
            response.set_cookie(
                key="refresh_token",
                value=raw_refresh,
                httponly=True,
                secure=not settings.DEBUG,
                samesite="Lax",
                max_age=30 * 24 * 60 * 60,
            )

        return response


class LogoutView(APIView):
    """
    Blacklists the refresh token and clears the secure HTTP-only cookie.
    """
    def post(self, request):
        raw_refresh = request.data.get("refresh") or request.COOKIES.get("refresh_token")
        if raw_refresh:
            try:
                token = RefreshToken(raw_refresh)
                token.blacklist()
            except Exception:
                pass

        response = Response(
            {"detail": "Successfully logged out."},
            status=status.HTTP_200_OK
        )
        response.delete_cookie("refresh_token")
        return response