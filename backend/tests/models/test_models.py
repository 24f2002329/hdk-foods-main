from decimal import Decimal
from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from accounts.models import Address
from products.models import Category, Product
from orders.models import Coupon, Order, OrderItem, PrepConfig
from authentication.utils import sanitize_text

User = get_user_model()


class ModelLogicTests(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Create test users
        self.customer_user = User.objects.create_user(
            phone_number="+918888888888",
            password="customerpassword123",
            name="Customer User",
            role="customer",
            is_phone_verified=True,
        )

        self.address = Address.objects.create(
            user=self.customer_user,
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
            base_prep_minutes=15,
        )

        self.prep_config = PrepConfig.get()
        self.prep_config.queue_multiplier = 2.0
        self.prep_config.rush_hour_bonus = 5
        self.prep_config.override_boost = 0
        self.prep_config.peak_weekdays = "4,5,6"
        self.prep_config.save()

    def _create_order(self):
        order = Order.objects.create(
            user=self.customer_user,
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

    def test_xss_input_sanitization(self):
        """
        Verify that XSS / script injections are stripped from text inputs.
        """
        payload = "<script>alert('XSS')</script>John Doe <p>Paragraph</p>"
        sanitized = sanitize_text(payload)
        self.assertEqual(sanitized, "John Doe Paragraph")

        # Test UserSerializer sanitization
        self.client.force_authenticate(user=self.customer_user)
        response = self.client.patch(
            "/api/me/", {"name": "<script>evil()</script>Good Name"}
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["name"], "Good Name")

    def test_percentage_coupon_with_cap(self):
        coupon = Coupon.objects.create(
            code="PCT20",
            discount_type="percentage",
            discount_value=Decimal("20.00"),
            max_discount_amount=Decimal("50.00"),
        )
        discount = coupon.compute_discount(Decimal("500.00"))
        self.assertEqual(discount, Decimal("50.00"))  # capped at 50

    def test_percentage_coupon_under_cap(self):
        coupon = Coupon.objects.create(
            code="PCT20B",
            discount_type="percentage",
            discount_value=Decimal("20.00"),
            max_discount_amount=Decimal("50.00"),
        )
        discount = coupon.compute_discount(Decimal("100.00"))
        self.assertEqual(discount, Decimal("20.00"))

    def test_calculate_prep_time_no_backlog(self):
        from orders.utils import calculate_predicted_prep_time

        pred = calculate_predicted_prep_time([self.product.id])
        self.assertTrue(pred >= 15)

    def test_calculate_prep_time_with_backlog(self):
        from orders.utils import calculate_predicted_prep_time

        self._create_order()
        self._create_order()

        pred = calculate_predicted_prep_time([self.product.id])
        self.assertTrue(pred >= 19)
