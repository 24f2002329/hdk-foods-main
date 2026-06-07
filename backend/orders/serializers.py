from rest_framework import serializers
from .models import Order, OrderItem



class OrderItemCreateSerializer(serializers.Serializer):
    product_id = serializers.IntegerField()
    quantity = serializers.IntegerField()


class OrderCreateSerializer(serializers.Serializer):

    address_id = serializers.IntegerField()

    payment_method = serializers.CharField()

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
    status = serializers.CharField()


class AssignDeliverySerializer(serializers.Serializer):
    delivery_user_id = (
        serializers.IntegerField()
    )



class OrderItemSerializer(serializers.ModelSerializer):

    class Meta:
        model = OrderItem
        fields = "__all__"


class OrderSerializer(serializers.ModelSerializer):

    items = OrderItemSerializer(
        many=True,
        read_only=True
    )

    class Meta:
        model = Order
        fields = "__all__"



