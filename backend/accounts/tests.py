from rest_framework import status
from rest_framework.test import APITestCase
from rest_framework_simplejwt.tokens import RefreshToken

from .models import Address, User


class AddressApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(phone_number="+919999999999")
        token = RefreshToken.for_user(self.user)
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {token.access_token}")

    def test_first_address_becomes_default(self):
        response = self.client.post(
            "/api/addresses/",
            data={
                "label": "Home",
                "house": "12A",
                "street": "Main Street",
                "landmark": "Near park",
                "city": "Indore",
                "pincode": "452001",
                "latitude": "22.719600",
                "longitude": "75.857700",
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertTrue(response.data["is_default"])

    def test_setting_default_unsets_previous_default(self):
        home = Address.objects.create(
            user=self.user,
            label="Home",
            house="12A",
            street="Main Street",
            city="Indore",
            pincode="452001",
            latitude="22.719600",
            longitude="75.857700",
            is_default=True,
        )

        response = self.client.post(
            "/api/addresses/",
            data={
                "label": "Work",
                "house": "21B",
                "street": "Market Road",
                "city": "Indore",
                "pincode": "452002",
                "latitude": "22.720000",
                "longitude": "75.860000",
                "is_default": True,
            },
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        home.refresh_from_db()

        self.assertFalse(home.is_default)
        self.assertTrue(Address.objects.get(pk=response.data["id"]).is_default)
