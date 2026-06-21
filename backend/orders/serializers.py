from rest_framework import serializers
from .models import Order, OrderItem



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
            "ready_for_pickup",
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



