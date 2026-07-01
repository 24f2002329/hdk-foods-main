import datetime
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase
from django.utils import timezone

from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

User = get_user_model()


class AuthenticationApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        cache.clear()

        # Create test users
        self.admin_user = User.objects.create_user(
            phone_number="+919999999999",
            password="adminpassword123",
            name="Admin User",
            role="admin",
            is_phone_verified=True,
        )
        self.customer_user = User.objects.create_user(
            phone_number="+918888888888",
            password="customerpassword123",
            name="Customer User",
            role="customer",
            is_phone_verified=True,
        )

    def tearDown(self):
        cache.clear()

    def test_jwt_token_lifetimes_and_rotation(self):
        """
        Verify access tokens have a lifetime of 15 minutes,
        and RTR (Refresh Token Rotation) rotates the token.
        """
        refresh = RefreshToken.for_user(self.customer_user)
        access_token = refresh.access_token

        # Test expiration delta is 15 minutes
        token_expiration = datetime.datetime.fromtimestamp(
            access_token["exp"], tz=datetime.timezone.utc
        )
        self.assertAlmostEqual(
            (token_expiration - timezone.now()).total_seconds(), 15 * 60, delta=30
        )

        # Test RTR rotation
        response = self.client.post(
            "/api/v1/auth/token/refresh/", {"refresh": str(refresh)}
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)

        new_refresh = response.cookies.get("refresh_token")
        self.assertIsNotNone(new_refresh)

    def test_send_sms_rate_limiting_by_phone(self):
        """
        Test that SMS requests are rate-limited to 3 requests per phone number per 15 mins.
        """
        phone = "+919900990099"

        # First 3 requests succeed
        for _ in range(3):
            response = self.client.post(
                "/api/v1/auth/send-sms/", {"phone_number": phone}
            )
            self.assertEqual(response.status_code, status.HTTP_200_OK)
            self.assertEqual(response.data["status"], "OTP sent")

        # 4th request gets 429
        response = self.client.post("/api/v1/auth/send-sms/", {"phone_number": phone})
        self.assertEqual(response.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn("Maximum 3 requests per 15 minutes", response.data["detail"])

    def test_send_sms_rate_limiting_by_ip(self):
        """
        Test that SMS requests are rate-limited to 10 requests per IP per hour.
        """
        for i in range(10):
            phone = f"+91990000000{i}"
            response = self.client.post(
                "/api/v1/auth/send-sms/",
                {"phone_number": phone},
                REMOTE_ADDR="192.168.1.50",
            )
            self.assertEqual(response.status_code, status.HTTP_200_OK)

        # 11th request gets 429
        response = self.client.post(
            "/api/v1/auth/send-sms/",
            {"phone_number": "+919900000010"},
            REMOTE_ADDR="192.168.1.50",
        )
        self.assertEqual(response.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn("Maximum 10 requests per hour", response.data["detail"])

    def test_secure_cookie_refresh_token_storage(self):
        """
        Verify that login sets a secure HttpOnly cookie for refresh token,
        and token/refresh can read it from the cookie.
        """
        # Login
        response = self.client.post(
            "/api/v1/auth/staff-login/",
            {"phone_number": "+919999999999", "password": "adminpassword123"},
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        # Check cookie
        self.assertIn("refresh_token", response.cookies)
        cookie = response.cookies["refresh_token"]
        self.assertTrue(cookie["httponly"])

        # Refresh using the cookie (sending empty refresh in body)
        self.client.cookies = response.cookies
        refresh_response = self.client.post("/api/v1/auth/token/refresh/", {})
        self.assertEqual(refresh_response.status_code, status.HTTP_200_OK)
        self.assertIn("access", refresh_response.data)
        self.assertIn("refresh_token", refresh_response.cookies)

    def test_logout_invalidates_token_and_clears_cookie(self):
        """
        Test that logout blacklists the refresh token and clears the cookie.
        """
        # Login to get cookie
        response = self.client.post(
            "/api/v1/auth/staff-login/",
            {"phone_number": "+919999999999", "password": "adminpassword123"},
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        refresh_token = response.cookies["refresh_token"].value

        # Logout
        self.client.cookies = response.cookies
        logout_response = self.client.post("/api/v1/auth/logout/", {})
        self.assertEqual(logout_response.status_code, status.HTTP_200_OK)

        # Cookie is cleared/expired
        self.assertEqual(logout_response.cookies["refresh_token"].value, "")

        # Refresh token is now blacklisted
        refresh_response = self.client.post(
            "/api/v1/auth/token/refresh/", {"refresh": refresh_token}
        )
        self.assertEqual(refresh_response.status_code, status.HTTP_401_UNAUTHORIZED)
