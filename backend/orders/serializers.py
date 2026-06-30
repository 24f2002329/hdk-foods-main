from rest_framework import serializers
from .models import Coupon, Order, OrderItem, OrderReview, ProductReview



class OrderItemCreateSerializer(serializers.Serializer):
    product_id = serializers.IntegerField()
    quantity = serializers.IntegerField()


class OrderCreateSerializer(serializers.Serializer):

    address_id = serializers.IntegerField()

    payment_method = serializers.CharField(
        required=False,
        allow_blank=True
    )

    delivery_notes = serializers.CharField(
        required=False,
        allow_blank=True
    )

    coupon_code = serializers.CharField(
        required=False,
        allow_blank=True,
        default=""
    )

    items = OrderItemCreateSerializer(
        many=True
    )


class ConfirmOrderSerializer(serializers.Serializer):
    estimated_preparation_time = (
        serializers.IntegerField()
    )


class RejectOrderSerializer(serializers.Serializer):
    reason = serializers.CharField()


class UpdateStatusSerializer(serializers.Serializer):
    status = serializers.ChoiceField(
        choices=[
            "pending_confirmation",
            "confirmed",
            "preparing",
            "out_for_delivery",
            "delivered",
            "cancelled",
            "rejected",
        ]
    )


class AssignDeliverySerializer(serializers.Serializer):
    delivery_user_id = (
        serializers.IntegerField()
    )


class SelectPaymentSerializer(serializers.Serializer):
    payment_method = serializers.ChoiceField(
        choices=["cod", "online"]
    )


class AdminPaymentMethodSerializer(serializers.Serializer):
    payment_method = serializers.ChoiceField(
        choices=["cod", "online"],
        required=False,
    )
    action = serializers.ChoiceField(
        choices=["change_method", "mark_paid"],
        required=False,
        default="change_method",
    )


class ApplyDiscountSerializer(serializers.Serializer):
    discount_amount = serializers.DecimalField(
        max_digits=10,
        decimal_places=2,
        min_value=0
    )
    discount_reason = serializers.CharField(
        required=False,
        allow_blank=True,
        default=""
    )


class AcknowledgeChangesSerializer(serializers.Serializer):
    accepted = serializers.BooleanField()



class OrderItemSerializer(serializers.ModelSerializer):

    product_name = serializers.CharField(
        source="product.name",
        read_only=True
    )

    class Meta:
        model = OrderItem
        fields = [
            "id",
            "product",
            "product_name",
            "quantity",
            "price"
        ]


class OrderAddressSerializer(serializers.Serializer):
    """Read-only snapshot of the delivery address for an order."""
    label = serializers.CharField()
    house = serializers.CharField()
    street = serializers.CharField()
    landmark = serializers.CharField()
    city = serializers.CharField()
    pincode = serializers.CharField()
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6)


class UpdateDeliveryLocationSerializer(serializers.Serializer):
    latitude = serializers.DecimalField(max_digits=9, decimal_places=6)
    longitude = serializers.DecimalField(max_digits=9, decimal_places=6)


class OrderSerializer(serializers.ModelSerializer):

    items = OrderItemSerializer(
        many=True,
        read_only=True
    )

    address_detail = serializers.SerializerMethodField()
    customer_name = serializers.SerializerMethodField()
    customer_phone = serializers.SerializerMethodField()

    class Meta:
        model = Order
        fields = "__all__"

    def get_address_detail(self, obj):
        if not obj.address_id:
            return None
        return OrderAddressSerializer(obj.address).data

    def get_customer_name(self, obj):
        return obj.user.name if obj.user_id else ''

    def get_customer_phone(self, obj):
        return obj.user.phone_number if obj.user_id else ''


class CouponSerializer(serializers.ModelSerializer):
    class Meta:
        model = Coupon
        fields = [
            'id', 'code', 'discount_type', 'discount_value',
            'min_order_amount', 'max_discount_amount',
            'is_active', 'valid_from', 'valid_until',
            'usage_limit', 'usage_count', 'created_at',
        ]
        read_only_fields = ['usage_count', 'created_at']


class CouponWriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Coupon
        fields = [
            'code', 'discount_type', 'discount_value',
            'min_order_amount', 'max_discount_amount',
            'is_active', 'valid_from', 'valid_until',
            'usage_limit',
        ]


class OrderReviewSerializer(serializers.ModelSerializer):
    customer_name = serializers.CharField(source="customer.name", read_only=True)
    customer_phone = serializers.CharField(source="customer.phone_number", read_only=True)
    order_number = serializers.CharField(source="order.order_number", read_only=True)

    class Meta:
        model = OrderReview
        fields = [
            "id",
            "order",
            "order_number",
            "customer",
            "customer_name",
            "customer_phone",
            "rating",
            "comment",
            "created_at",
        ]


from .models import OrderMessage

class OrderMessageSerializer(serializers.ModelSerializer):
    sender_name = serializers.CharField(source="sender.name", read_only=True)
    sender_phone = serializers.CharField(source="sender.phone_number", read_only=True)

    class Meta:
        model = OrderMessage
        fields = [
            "id",
            "order",
            "sender",
            "sender_name",
            "sender_phone",
            "message",
            "is_admin",
            "created_at",
        ]
        read_only_fields = ["sender", "is_admin"]


class ProductReviewSerializer(serializers.ModelSerializer):
    product_name = serializers.CharField(source="product.name", read_only=True)
    customer_name = serializers.CharField(source="customer.name", read_only=True)
    customer_phone = serializers.CharField(source="customer.phone_number", read_only=True)
    order_number = serializers.CharField(source="order.order_number", read_only=True)

    class Meta:
        model = ProductReview
        fields = [
            "id",
            "product",
            "product_name",
            "customer",
            "customer_name",
            "customer_phone",
            "order",
            "order_number",
            "rating",
            "comment",
            "created_at",
        ]
