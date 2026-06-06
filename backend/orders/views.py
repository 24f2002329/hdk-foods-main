# from django.shortcuts import render

# Create your views here.

from decimal import Decimal
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import Address
from products.models import Product

from .models import Order, OrderItem
from .serializers import (
    ConfirmOrderSerializer,
    OrderCreateSerializer,
    OrderSerializer,
    RejectOrderSerializer,
    UpdateStatusSerializer
)

from django.utils import timezone
from datetime import timedelta



class CreateOrderView(APIView):

    def post(self, request):

        serializer = OrderCreateSerializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        data = serializer.validated_data

        address = Address.objects.get(
            id=data["address_id"]
        )

        total_amount = Decimal("0.00")

        order = Order.objects.create(
            user=address.user,
            address=address,
            payment_method=data["payment_method"],
            delivery_notes=data.get(
                "delivery_notes",
                ""
            ),
            total_amount=0
        )

        for item in data["items"]:

            product = Product.objects.get(
                id=item["product_id"]
            )

            quantity = item["quantity"]

            price = product.price

            total_amount += (
                price * quantity
            )

            OrderItem.objects.create(
                order=order,
                product=product,
                quantity=quantity,
                price=price
            )

        order.total_amount = total_amount
        order.save()

        return Response(
            OrderSerializer(order).data,
            status=status.HTTP_201_CREATED
        )
    



class OrderListView(generics.ListAPIView):

    queryset = Order.objects.all().order_by(
        "-created_at"
    )

    serializer_class = OrderSerializer




class ConfirmOrderView(APIView):

    def patch(self, request, pk):

        order = Order.objects.get(
            pk=pk
        )

        serializer = (
            ConfirmOrderSerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        prep_time = serializer.validated_data[
            "estimated_preparation_time"
        ]

        order.status = "confirmed"

        order.confirmed_at = (
            timezone.now()
        )

        order.estimated_preparation_time = (
            prep_time
        )

        order.estimated_delivery_time = (
            timezone.now()
            + timedelta(
                minutes=prep_time + 15
            )
        )

        order.save()

        return Response(
            OrderSerializer(order).data
        )




class RejectOrderView(APIView):

    def patch(self, request, pk):

        order = Order.objects.get(
            pk=pk
        )

        serializer = (
            RejectOrderSerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        order.status = "rejected"

        order.rejection_reason = (
            serializer.validated_data[
                "reason"
            ]
        )

        order.save()

        return Response(
            OrderSerializer(order).data
        )




class UpdateOrderStatusView(APIView):

    def patch(self, request, pk):

        order = Order.objects.get(
            pk=pk
        )

        serializer = (
            UpdateStatusSerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        order.status = (
            serializer.validated_data[
                "status"
            ]
        )

        order.save()

        return Response(
            OrderSerializer(order).data
        )