# from django.shortcuts import render

# Create your views here.

from decimal import Decimal
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import Address, User
from authentication.permissions import (
    IsAdminOrChef, 
    IsAdmin, 
    IsDelivery
)
from products.models import Product

from .models import Order, OrderItem
from .serializers import (
    AssignDeliverySerializer,
    ConfirmOrderSerializer,
    OrderCreateSerializer,
    OrderSerializer,
    RejectOrderSerializer,
    UpdateStatusSerializer
)

from django.utils import timezone
from datetime import timedelta

from django.db.models import Sum

from rest_framework.permissions import IsAuthenticated



class CreateOrderView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    def post(self, request):

        serializer = OrderCreateSerializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        data = serializer.validated_data

        address = Address.objects.get(
            id=data["address_id"],
            user=request.user
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



class MyOrdersView(generics.ListAPIView):
    serializer_class = OrderSerializer
    
    permission_classes = [
        IsAuthenticated
    ]

    def get_queryset(self):
        return Order.objects.filter(
            user=self.request.user
        ).order_by(
            "-created_at"
        )


class OrderDetailView(generics.RetrieveAPIView):
    serializer_class = OrderSerializer
    permission_classes = [
        IsAuthenticated
    ]

    def get_queryset(self):
        return Order.objects.filter(
            user=self.request.user
        )
    


class ConfirmOrderView(APIView):

    permission_classes = [
        IsAdminOrChef
    ]

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

    permission_classes = [
        IsAdminOrChef
    ]
    
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

    permission_classes = [
        IsAdminOrChef
    ]

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



class AssignDeliveryView(APIView):

    permission_classes = [
        IsAdmin
    ]

    def patch(
        self,
        request,
        pk
    ):

        order = Order.objects.get(
            pk=pk
        )

        serializer = (
            AssignDeliverySerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        delivery_user = User.objects.get(
            id=serializer.validated_data[
                "delivery_user_id"
            ],
            role="delivery"
        )

        order.assigned_delivery = (
            delivery_user
        )

        order.save()

        return Response(
            OrderSerializer(order).data
        )
    

class DeliveryOrdersView(generics.ListAPIView):

    serializer_class = (
        OrderSerializer
    )

    permission_classes = [
        IsDelivery
    ]

    def get_queryset(self):

        return Order.objects.filter(
            assigned_delivery=
            self.request.user
        ).order_by(
            "-created_at"
        )


class PendingOrdersView(generics.ListAPIView):

    serializer_class = (
        OrderSerializer
    )

    permission_classes = [
        IsAdminOrChef
    ]

    def get_queryset(self):

        return Order.objects.filter(
            status=
            "pending_confirmation"
        ).order_by(
            "created_at"
        )






class AdminDashboardView(APIView):

    permission_classes = [
        IsAdmin
    ]

    def get(
        self,
        request
    ):

        today = (
            timezone.now()
            .date()
        )

        today_orders = (
            Order.objects.filter(
                created_at__date=today
            )
            .count()
        )

        pending_orders = (
            Order.objects.filter(
                status=
                "pending_confirmation"
            )
            .count()
        )

        active_deliveries = (
            Order.objects.filter(
                status=
                "out_for_delivery"
            )
            .count()
        )

        today_revenue = (
            Order.objects.filter(
                created_at__date=today,
                payment_status="paid"
            )
            .aggregate(
                total=
                Sum(
                    "total_amount"
                )
            )["total"]
            or 0
        )

        return Response(
            {
                "today_orders":
                    today_orders,

                "pending_orders":
                    pending_orders,

                "active_deliveries":
                    active_deliveries,

                "today_revenue":
                    today_revenue,
            }
        )


    
