from decimal import Decimal
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import Address
from products.models import Category, Product
from orders.models import Order, OrderItem

User = get_user_model()


def _jwt(user):
    return str(RefreshToken.for_user(user).access_token)


def _auth(client, user):
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {_jwt(user)}")


class RbacPermissionsTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Create test users
        self.admin = User.objects.create_user(
            phone_number="+919999999999",
            password="adminpassword123",
            name="Admin User",
            role="admin",
            is_phone_verified=True,
            is_staff=True,
        )
        self.customer = User.objects.create_user(
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
        self.delivery = User.objects.create_user(
            phone_number="+916666666666",
            password="deliverypassword123",
            name="Delivery User",
            role="delivery",
            is_phone_verified=True,
        )

        self.address = Address.objects.create(
            user=self.customer,
            label="Home",
            house="1A",
            street="Main St",
            city="Mumbai",
            pincode="400001",
            latitude=Decimal("19.0"),
            longitude=Decimal("72.8"),
        )

        self.category = Category.objects.create(name="Burgers")
        self.product = Product.objects.create(
            category=self.category,
            name="Classic Burger",
            price=Decimal("199.00"),
        )

    def _create_order(self, user=None):
        user = user or self.customer
        order = Order.objects.create(
            user=user,
            address=self.address,
            total_amount=Decimal("199.00"),
            payment_method="cod",
        )
        OrderItem.objects.create(
            order=order,
            product=self.product,
            quantity=1,
            price=Decimal("199.00"),
        )
        return order

    def test_rbac_delivery_location_tracking(self):
        """
        Verify that standard customers cannot access other customers' delivery location streams.
        """
        order = self._create_order()

        # Test that owner customer CAN access it
        _auth(self.client, self.customer)
        response = self.client.get(f"/api/v1/orders/{order.id}/delivery-location/get/")
        self.assertEqual(response.status_code, 200)

        # Test that OTHER customer CANNOT access it
        _auth(self.client, self.other_customer)
        response = self.client.get(f"/api/v1/orders/{order.id}/delivery-location/get/")
        self.assertEqual(response.status_code, 403)

        # Test that admin CAN access it
        _auth(self.client, self.admin)
        response = self.client.get(f"/api/v1/orders/{order.id}/delivery-location/get/")
        self.assertEqual(response.status_code, 200)

    def test_customer_cannot_create_product(self):
        _auth(self.client, self.customer)
        res = self.client.post(
            "/api/v1/products/create/",
            {
                "category": self.category.id,
                "name": "Should Fail",
                "price": "100.00",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 403)

    def test_customer_cannot_confirm_order(self):
        order = self._create_order()
        _auth(self.client, self.customer)
        res = self.client.patch(
            f"/api/v1/orders/{order.id}/confirm/",
            {"estimated_preparation_time": 20},
            format="json",
        )
        self.assertEqual(res.status_code, 403)

    def test_delivery_can_only_mark_delivered(self):
        order = self._create_order()
        order.status = "out_for_delivery"
        order.assigned_delivery = self.delivery
        order.save()
        _auth(self.client, self.delivery)
        res = self.client.patch(
            f"/api/v1/orders/{order.id}/status/",
            {"status": "preparing"},
            format="json",
        )
        self.assertEqual(res.status_code, 403)

    def test_customer_cannot_access_dashboard(self):
        _auth(self.client, self.customer)
        res = self.client.get("/api/v1/orders/admin/dashboard/")
        self.assertEqual(res.status_code, 403)

    def test_prep_config_admin_endpoints(self):
        _auth(self.client, self.customer)
        res = self.client.get("/api/v1/orders/admin/prep-config/")
        self.assertEqual(res.status_code, 403)
