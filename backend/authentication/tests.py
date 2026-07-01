import datetime
from django.contrib.auth import get_user_model
from django.core.cache import cache
from django.test import TestCase, override_settings
from django.utils import timezone
from datetime import timedelta

from rest_framework import status
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken, RefreshToken

from accounts.models import Address
from authentication.utils import sanitize_text

User = get_user_model()


class AuthenticationSecurityTests(TestCase):
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
        self.other_customer = User.objects.create_user(
            phone_number="+917777777777",
            password="otherpassword123",
            name="Other Customer",
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
            "/api/auth/token/refresh/", {"refresh": str(refresh)}
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIn("access", response.data)

        # Since rotate refresh tokens is True, we expect a new refresh token (either in body or cookies)
        # simple_jwt sends it in the JSON response by default, and we set it in the cookie too
        new_refresh = response.cookies.get("refresh_token")
        self.assertIsNotNone(new_refresh)

    def test_send_sms_rate_limiting_by_phone(self):
        """
        Test that SMS requests are rate-limited to 3 requests per phone number per 15 mins.
        """
        phone = "+919900990099"

        # First 3 requests succeed
        for _ in range(3):
            response = self.client.post("/api/auth/send-sms/", {"phone_number": phone})
            self.assertEqual(response.status_code, status.HTTP_200_OK)
            self.assertEqual(response.data["status"], "OTP sent")

        # 4th request gets 429
        response = self.client.post("/api/auth/send-sms/", {"phone_number": phone})
        self.assertEqual(response.status_code, status.HTTP_429_TOO_MANY_REQUESTS)
        self.assertIn("Maximum 3 requests per 15 minutes", response.data["detail"])

    def test_send_sms_rate_limiting_by_ip(self):
        """
        Test that SMS requests are rate-limited to 10 requests per IP per hour.
        """
        # We vary the phone number, but keep the IP address constant
        for i in range(10):
            phone = f"+91990000000{i}"
            response = self.client.post(
                "/api/auth/send-sms/",
                {"phone_number": phone},
                REMOTE_ADDR="192.168.1.50",
            )
            self.assertEqual(response.status_code, status.HTTP_200_OK)

        # 11th request gets 429
        response = self.client.post(
            "/api/auth/send-sms/",
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
            "/api/auth/staff-login/",
            {"phone_number": "+919999999999", "password": "adminpassword123"},
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        # Check cookie
        self.assertIn("refresh_token", response.cookies)
        cookie = response.cookies["refresh_token"]
        self.assertTrue(cookie["httponly"])

        # Refresh using the cookie (sending empty refresh in body)
        # Clear body to test that refresh token is pulled from cookies
        self.client.cookies = response.cookies
        refresh_response = self.client.post("/api/auth/token/refresh/", {})
        self.assertEqual(refresh_response.status_code, status.HTTP_200_OK)
        self.assertIn("access", refresh_response.data)
        self.assertIn("refresh_token", refresh_response.cookies)

    def test_logout_invalidates_token_and_clears_cookie(self):
        """
        Test that logout blacklists the refresh token and clears the cookie.
        """
        # Login to get cookie
        response = self.client.post(
            "/api/auth/staff-login/",
            {"phone_number": "+919999999999", "password": "adminpassword123"},
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        refresh_token = response.cookies["refresh_token"].value

        # Logout
        self.client.cookies = response.cookies
        logout_response = self.client.post("/api/auth/logout/", {})
        self.assertEqual(logout_response.status_code, status.HTTP_200_OK)

        # Cookie is cleared/expired
        self.assertEqual(logout_response.cookies["refresh_token"].value, "")

        # Refresh token is now blacklisted
        refresh_response = self.client.post(
            "/api/auth/token/refresh/", {"refresh": refresh_token}
        )
        self.assertEqual(refresh_response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_xss_input_sanitization(self):
        """
        Verify that XSS / script injections are stripped from text inputs.
        """
        payload = "<script>alert('XSS')</script>John Doe <p>Paragraph</p>"
        sanitized = sanitize_text(payload)
        # Verify script tag and p tag are stripped
        self.assertEqual(sanitized, "John Doe Paragraph")

        # Test UserSerializer sanitization
        self.client.force_authenticate(user=self.customer_user)
        response = self.client.patch(
            "/api/me/", {"name": "<script>evil()</script>Good Name"}
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["name"], "Good Name")

        # Test AddressSerializer sanitization
        addr_response = self.client.post(
            "/api/addresses/",
            {
                "label": "Home",
                "house": "<script>alert(1)</script>Flat 404",
                "street": "Super Street <img src=x onerror=alert(1)>",
                "landmark": "Near Shop",
                "city": "Sojat Road",
                "pincode": "306103",
                "latitude": "25.8610",
                "longitude": "73.7490",
            },
        )
        self.assertEqual(addr_response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(addr_response.data["label"], "Home")
        self.assertEqual(addr_response.data["house"], "Flat 404")
        self.assertEqual(addr_response.data["street"], "Super Street")

    def test_rbac_delivery_location_tracking(self):
        """
        Verify that standard customers cannot access other customers' delivery location streams.
        """
        # Create an order under customer_user
        from orders.models import Order

        order = Order.objects.create(
            user=self.customer_user,
            address=Address.objects.create(
                user=self.customer_user,
                label="Home",
                house="123",
                street="St",
                city="City",
                pincode="306103",
                latitude="25.8610",
                longitude="73.7490",
            ),
            total_amount=100.00,
            status="confirmed",
            delivery_latitude="25.8615",
            delivery_longitude="73.7495",
        )

        # Test that owner customer CAN access it
        self.client.force_authenticate(user=self.customer_user)
        response = self.client.get(f"/api/orders/{order.id}/delivery-location/get/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["available"], True)

        # Test that OTHER customer CANNOT access it
        self.client.force_authenticate(user=self.other_customer)
        response = self.client.get(f"/api/orders/{order.id}/delivery-location/get/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

        # Test that admin CAN access it
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get(f"/api/orders/{order.id}/delivery-location/get/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
