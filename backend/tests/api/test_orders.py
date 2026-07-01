from decimal import Decimal
from django.test import TestCase
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import Address, User
from products.models import Category, Product
from orders.models import Coupon, Order, OrderItem


def _jwt(user):
    return str(RefreshToken.for_user(user).access_token)


def _auth(client, user):
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {_jwt(user)}")


class BaseOrderTest(TestCase):
    def setUp(self):
        self.client = APIClient()

        from app_config.models import SiteConfig
        from datetime import time

        SiteConfig.objects.update_or_create(
            pk=1,
            defaults={
                "is_store_open": True,
                "store_open_time": time(0, 0),
                "store_close_time": time(23, 59, 59),
            },
        )

        self.admin = User.objects.create_user(
            phone_number="9000000001", role="admin", is_staff=True
        )
        self.customer = User.objects.create_user(
            phone_number="9000000002", role="customer"
        )
        self.delivery = User.objects.create_user(
            phone_number="9000000003", role="delivery"
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


class CreateOrderTest(BaseOrderTest):
    def test_customer_can_create_order(self):
        _auth(self.client, self.customer)
        res = self.client.post(
            "/api/v1/orders/create/",
            {
                "address_id": self.address.id,
                "payment_method": "cod",
                "items": [{"product_id": self.product.id, "quantity": 2}],
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data["status"], "pending_confirmation")
        self.assertEqual(Decimal(res.data["total_amount"]), Decimal("398.00"))

    def test_unauthenticated_cannot_create_order(self):
        res = self.client.post(
            "/api/v1/orders/create/",
            {
                "address_id": self.address.id,
                "items": [{"product_id": self.product.id, "quantity": 1}],
            },
            format="json",
        )
        self.assertEqual(res.status_code, 401)

    def test_create_order_with_valid_coupon(self):
        coupon = Coupon.objects.create(
            code="SAVE50", discount_type="flat", discount_value=Decimal("50.00")
        )
        _auth(self.client, self.customer)
        res = self.client.post(
            "/api/v1/orders/create/",
            {
                "address_id": self.address.id,
                "payment_method": "cod",
                "coupon_code": "SAVE50",
                "items": [{"product_id": self.product.id, "quantity": 1}],
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertEqual(Decimal(res.data["discount_amount"]), Decimal("50.00"))
        self.assertEqual(Decimal(res.data["total_amount"]), Decimal("149.00"))
        coupon.refresh_from_db()
        self.assertEqual(coupon.usage_count, 1)

    def test_create_order_with_invalid_coupon(self):
        _auth(self.client, self.customer)
        res = self.client.post(
            "/api/v1/orders/create/",
            {
                "address_id": self.address.id,
                "coupon_code": "INVALID",
                "items": [{"product_id": self.product.id, "quantity": 1}],
            },
            format="json",
        )
        self.assertEqual(res.status_code, 400)


class ConfirmRejectOrderTest(BaseOrderTest):
    def test_admin_confirms_order(self):
        order = self._create_order()
        _auth(self.client, self.admin)
        res = self.client.patch(
            f"/api/v1/orders/{order.id}/confirm/",
            {"estimated_preparation_time": 20},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], "confirmed")

    def test_admin_rejects_order(self):
        order = self._create_order()
        _auth(self.client, self.admin)
        res = self.client.patch(
            f"/api/v1/orders/{order.id}/reject/",
            {"reason": "Out of stock"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], "rejected")


class UpdateOrderStatusTest(BaseOrderTest):
    def test_admin_updates_status(self):
        order = self._create_order()
        order.status = "confirmed"
        order.save()
        _auth(self.client, self.admin)
        res = self.client.patch(
            f"/api/v1/orders/{order.id}/status/",
            {"status": "preparing"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], "preparing")

    def test_delivery_marks_own_order_delivered(self):
        order = self._create_order()
        order.status = "out_for_delivery"
        order.payment_status = "paid"
        order.assigned_delivery = self.delivery
        order.save()
        _auth(self.client, self.delivery)
        res = self.client.patch(
            f"/api/v1/orders/{order.id}/status/",
            {"status": "delivered"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)

    def test_unpaid_order_cannot_be_marked_delivered(self):
        order = self._create_order()
        order.status = "out_for_delivery"
        order.payment_method = "online"
        order.payment_status = "pending"
        order.assigned_delivery = self.delivery
        order.save()
        _auth(self.client, self.delivery)
        res = self.client.patch(
            f"/api/v1/orders/{order.id}/status/",
            {"status": "delivered"},
            format="json",
        )
        self.assertEqual(res.status_code, 400)
        self.assertIn("Cannot mark delivered", res.data["detail"])

    def test_dynamic_loyalty_coins_earned(self):
        from app_config.models import SiteConfig

        config = SiteConfig.get()
        config.loyalty_coins_percentage = 5
        config.save()

        order = self._create_order()
        order.status = "out_for_delivery"
        order.payment_status = "paid"
        order.assigned_delivery = self.delivery
        order.save()

        _auth(self.client, self.delivery)
        res = self.client.patch(
            f"/api/v1/orders/{order.id}/status/",
            {"status": "delivered"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)

        self.assertEqual(res.data["coins_earned"], 9)
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.loyalty_coins, 9)

        config.loyalty_coins_percentage = 15
        config.save()

        order2 = self._create_order()
        order2.status = "out_for_delivery"
        order2.payment_status = "paid"
        order2.assigned_delivery = self.delivery
        order2.save()

        res2 = self.client.patch(
            f"/api/v1/orders/{order2.id}/status/",
            {"status": "delivered"},
            format="json",
        )
        self.assertEqual(res2.status_code, 200)

        self.assertEqual(res2.data["coins_earned"], 29)
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.loyalty_coins, 38)


class PaginationTest(BaseOrderTest):
    def test_order_list_paginated(self):
        for _ in range(25):
            self._create_order()
        _auth(self.client, self.admin)
        res = self.client.get("/api/v1/orders/")
        self.assertEqual(res.status_code, 200)
        self.assertIn("results", res.data)
        self.assertIn("count", res.data)
        self.assertEqual(len(res.data["results"]), 20)

    def test_my_orders_paginated(self):
        for _ in range(25):
            self._create_order()
        _auth(self.client, self.customer)
        res = self.client.get("/api/v1/orders/my-orders/")
        self.assertEqual(res.status_code, 200)
        self.assertIn("results", res.data)

    def test_customer_list_paginated(self):
        for i in range(25):
            User.objects.create_user(phone_number=f"800000{i:04d}", role="customer")
        _auth(self.client, self.admin)
        res = self.client.get("/api/v1/customers/")
        self.assertEqual(res.status_code, 200)
        self.assertIn("results", res.data)


class AdminDashboardTest(BaseOrderTest):
    def test_dashboard_today(self):
        self._create_order()
        _auth(self.client, self.admin)
        res = self.client.get("/api/v1/orders/admin/dashboard/")
        self.assertEqual(res.status_code, 200)
        self.assertIn("total_orders", res.data)
        self.assertIn("pending_orders", res.data)

    def test_analytics_endpoint(self):
        self._create_order()
        _auth(self.client, self.admin)
        res = self.client.get("/api/v1/orders/admin/analytics/?days=7")
        self.assertEqual(res.status_code, 200)
        self.assertIn("data", res.data)
        self.assertEqual(res.data["days"], 7)


class CouponTest(BaseOrderTest):
    def setUp(self):
        super().setUp()
        self.coupon = Coupon.objects.create(
            code="FLAT100",
            discount_type="flat",
            discount_value=Decimal("100.00"),
            min_order_amount=Decimal("150.00"),
        )

    def test_validate_valid_coupon(self):
        _auth(self.client, self.customer)
        res = self.client.post(
            "/api/v1/orders/coupons/validate/",
            {
                "code": "FLAT100",
                "order_total": "300.00",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertTrue(res.data["valid"])
        self.assertEqual(Decimal(res.data["discount_amount"]), Decimal("100.00"))

    def test_validate_below_minimum(self):
        _auth(self.client, self.customer)
        res = self.client.post(
            "/api/v1/orders/coupons/validate/",
            {
                "code": "FLAT100",
                "order_total": "100.00",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data["valid"])

    def test_validate_invalid_code(self):
        _auth(self.client, self.customer)
        res = self.client.post(
            "/api/v1/orders/coupons/validate/",
            {
                "code": "NOSUCHCODE",
                "order_total": "300.00",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data["valid"])

    def test_admin_creates_coupon(self):
        _auth(self.client, self.admin)
        res = self.client.post(
            "/api/v1/orders/coupons/",
            {
                "code": "PERCENT10",
                "discount_type": "percentage",
                "discount_value": "10.00",
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data["code"], "PERCENT10")

    def test_admin_toggles_coupon(self):
        _auth(self.client, self.admin)
        res = self.client.patch(f"/api/v1/orders/coupons/{self.coupon.id}/toggle/")
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data["is_active"])


class PredictPrepTimeAPITest(BaseOrderTest):
    def setUp(self):
        super().setUp()
        self.product.base_prep_minutes = 15
        self.product.save()

    def test_predict_prep_time_view(self):
        _auth(self.client, self.customer)
        res = self.client.get(
            f"/api/v1/orders/predict-prep-time/?product_ids={self.product.id}"
        )
        self.assertEqual(res.status_code, 200)
        self.assertIn("predicted_preparation_time", res.data)
        self.assertIn("predicted_delivery_time_minutes", res.data)
        self.assertEqual(
            res.data["predicted_delivery_time_minutes"],
            res.data["predicted_preparation_time"] + 15,
        )

    def test_order_serializer_includes_predicted_prep_time(self):
        order = self._create_order()
        _auth(self.client, self.customer)
        res = self.client.get(f"/api/v1/orders/{order.id}/")
        self.assertEqual(res.status_code, 200)
        self.assertIn("predicted_preparation_time", res.data)
