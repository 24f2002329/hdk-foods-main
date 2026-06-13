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


class OrderSerializer(serializers.ModelSerializer):

    items = OrderItemSerializer(
        many=True,
        read_only=True
    )

    class Meta:
        model = Order
        fields = "__all__"



