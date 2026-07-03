from decimal import Decimal
from django.test import TestCase
from django.utils import timezone
from unittest.mock import patch
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import RefreshToken

from accounts.models import Address, User
from products.models import Category, Product
from orders.models import Coupon, Order, OrderItem


def _jwt(user):
    return str(RefreshToken.for_user(user).access_token)


def _auth(client, user):
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {_jwt(user)}")


class OrderLifecycleTest(TestCase):
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
            phone_number="9000000002", role="customer", loyalty_coins=100
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
        self.product1 = Product.objects.create(
            category=self.category,
            name="Classic Burger",
            price=Decimal("150.00"),
        )
        self.product2 = Product.objects.create(
            category=self.category,
            name="Cheese Burger",
            price=Decimal("200.00"),
        )

    def _create_pending_order(self, user=None):
        user = user or self.customer
        order = Order.objects.create(
            user=user,
            address=self.address,
            total_amount=Decimal("150.00"),
            payment_method="cod",
            status="pending_confirmation",
        )
        OrderItem.objects.create(
            order=order,
            product=self.product1,
            quantity=1,
            price=Decimal("150.00"),
        )
        return order

    @patch("authentication.firebase.send_push")
    def test_admin_manually_places_order(self, mock_send_push):
        _auth(self.client, self.admin)
        coupon = Coupon.objects.create(
            code="MANUAL50",
            discount_type="flat",
            discount_value=Decimal("50.00"),
            is_active=True,
            valid_from=timezone.now() - timezone.timedelta(days=1),
            valid_until=timezone.now() + timezone.timedelta(days=1),
        )

        res = self.client.post(
            "/api/v1/orders/admin/create/",
            {
                "phone_number": "9876543210",
                "customer_name": "John Doe",
                "delivery_type": "delivery",
                "house": "45B",
                "street": "Park Road",
                "city": "Mumbai",
                "pincode": "400002",
                "coupon_code": "MANUAL50",
                "items": [{"product_id": self.product1.id, "quantity": 2}],
            },
            format="json",
        )
        self.assertEqual(res.status_code, 201)
        self.assertEqual(res.data["status"], "confirmed")
        self.assertEqual(Decimal(res.data["discount_amount"]), Decimal("50.00"))
        self.assertEqual(Decimal(res.data["total_amount"]), Decimal("250.00"))

        # Verify user was created
        user = User.objects.get(phone_number="+919876543210")
        self.assertEqual(user.name, "John Doe")
        self.assertEqual(user.role, "customer")

        # Verify address was created
        address = Address.objects.filter(user=user, house="45B").first()
        self.assertIsNotNone(address)
        self.assertEqual(address.street, "Park Road")
        self.assertEqual(address.pincode, "400002")

        mock_send_push.assert_called()

    def test_admin_edits_order_items_recalculates_coupon(self):
        coupon = Coupon.objects.create(
            code="FLAT30",
            discount_type="flat",
            discount_value=Decimal("30.00"),
            min_order_amount=Decimal("160.00"),
        )
        order = Order.objects.create(
            user=self.customer,
            address=self.address,
            total_amount=Decimal("170.00"),
            discount_amount=Decimal("30.00"),
            discount_reason="Coupon: FLAT30",
            payment_method="cod",
            status="pending_confirmation",
        )
        OrderItem.objects.create(
            order=order,
            product=self.product2,
            quantity=1,
            price=Decimal("200.00"),
        )

        _auth(self.client, self.admin)
        # Edit order items to drop total below coupon minimum
        res = self.client.patch(
            f"/api/v1/orders/{order.id}/edit-items/",
            {
                "items": [{"product_id": self.product1.id, "quantity": 1}],
            },
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(Decimal(res.data["total_amount"]), Decimal("150.00"))
        # Coupon discount should be invalidated because 150 < 160 (min_order_amount)
        self.assertEqual(Decimal(res.data["discount_amount"]), Decimal("0.00"))

    @patch("authentication.firebase.send_push")
    @patch("services.payments.initiate_cashfree_refund")
    def test_admin_rejects_order_initiates_refund_and_restores_coins(
        self, mock_refund, mock_send_push
    ):
        mock_refund.return_value = True

        order = self._create_pending_order()
        order.payment_method = "online"
        order.payment_status = "paid"
        order.coins_redeemed = 40
        order.save()

        # Deduct loyalty coins from customer
        self.customer.loyalty_coins = 60
        self.customer.save()

        _auth(self.client, self.admin)
        res = self.client.patch(
            f"/api/v1/orders/{order.id}/reject/",
            {"reason": "Out of stock"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], "rejected")
        self.assertEqual(res.data["payment_status"], "refunded")
        self.assertEqual(res.data["refund_status"], "initiated")

        # Verify customer loyalty coins are restored
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.loyalty_coins, 100)

        mock_refund.assert_called_once_with(order, "Out of stock")

    @patch("authentication.firebase.send_push")
    @patch("services.payments.initiate_cashfree_refund")
    def test_admin_cancels_order_initiates_refund_and_restores_coins(
        self, mock_refund, mock_send_push
    ):
        mock_refund.return_value = True

        order = self._create_pending_order()
        order.status = "confirmed"
        order.payment_method = "online"
        order.payment_status = "paid"
        order.coins_redeemed = 25
        order.save()

        # Deduct loyalty coins from customer
        self.customer.loyalty_coins = 75
        self.customer.save()

        _auth(self.client, self.admin)
        res = self.client.post(
            f"/api/v1/orders/{order.id}/admin-cancel/",
            {"reason": "Kitchen issues"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], "cancelled")
        self.assertEqual(res.data["payment_status"], "refunded")
        self.assertEqual(res.data["refund_status"], "initiated")

        # Verify customer loyalty coins are restored
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.loyalty_coins, 100)

        mock_refund.assert_called_once()

    @patch("authentication.firebase.send_push")
    @patch("services.payments.initiate_cashfree_refund")
    def test_admin_approves_customer_cancellation_request(
        self, mock_refund, mock_send_push
    ):
        mock_refund.return_value = True

        order = self._create_pending_order()
        order.status = "confirmed"
        order.cancellation_requested = True
        order.cancellation_reason = "Customer changed mind"
        order.payment_method = "online"
        order.payment_status = "paid"
        order.coins_redeemed = 10
        order.save()

        self.customer.loyalty_coins = 90
        self.customer.save()

        _auth(self.client, self.admin)
        res = self.client.post(
            f"/api/v1/orders/{order.id}/admin-handle-cancellation/",
            {"action": "approve"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], "cancelled")
        self.assertEqual(res.data["payment_status"], "refunded")
        self.assertEqual(res.data["refund_status"], "initiated")

        # Verify customer loyalty coins are restored
        self.customer.refresh_from_db()
        self.assertEqual(self.customer.loyalty_coins, 100)

        mock_refund.assert_called_once()

    @patch("authentication.firebase.send_push")
    @patch("services.payments.initiate_cashfree_refund")
    def test_admin_rejects_customer_cancellation_request(
        self, mock_refund, mock_send_push
    ):
        order = self._create_pending_order()
        order.status = "confirmed"
        order.cancellation_requested = True
        order.cancellation_reason = "Customer changed mind"
        order.save()

        _auth(self.client, self.admin)
        res = self.client.post(
            f"/api/v1/orders/{order.id}/admin-handle-cancellation/",
            {"action": "reject"},
            format="json",
        )
        self.assertEqual(res.status_code, 200)
        self.assertEqual(res.data["status"], "confirmed")
        self.assertFalse(res.data["cancellation_requested"])

        # No refund should be triggered
        mock_refund.assert_not_called()
