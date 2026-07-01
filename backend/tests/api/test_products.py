from decimal import Decimal
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import User
from products.models import Category, Product


def _auth(client, user):
    token = str(RefreshToken.for_user(user).access_token)
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")


class ProductAPITest(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.admin = User.objects.create_user(
            phone_number="9100000001", role="admin", is_staff=True
        )
        self.category = Category.objects.create(name="Pizzas")
        self.product = Product.objects.create(
            category=self.category,
            name="Margherita",
            price=Decimal("299.00"),
            is_available=True,
        )

    def test_public_product_list(self):
        res = self.client.get("/api/v1/products/")
        self.assertEqual(res.status_code, 200)
        self.assertGreaterEqual(len(res.data), 1)

    def test_admin_creates_product(self):
        _auth(self.client, self.admin)
        res = self.client.post(
            "/api/v1/products/create/",
            {
                "category": self.category.id,
                "name": "Pepperoni",
                "price": "349.00",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)

    def test_toggle_availability(self):
        _auth(self.client, self.admin)
        res = self.client.patch(f"/api/v1/products/{self.product.id}/toggle/")
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data["is_available"])

    def test_update_product(self):
        _auth(self.client, self.admin)
        res = self.client.patch(
            f"/api/v1/products/{self.product.id}/update/",
            {
                "price": "320.00",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(Decimal(res.data["price"]), Decimal("320.00"))

    def test_delete_product(self):
        _auth(self.client, self.admin)
        res = self.client.delete(f"/api/v1/products/{self.product.id}/delete/")
        self.assertEqual(res.status_code, 204)
        self.assertFalse(Product.objects.filter(pk=self.product.id).exists())

    def test_featured_products(self):
        self.product.is_featured = True
        self.product.save()
        res = self.client.get("/api/v1/products/featured/")
        self.assertEqual(res.status_code, 200)
        self.assertEqual(len(res.data), 1)
