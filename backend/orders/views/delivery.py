import logging
from django.utils import timezone
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.permissions import IsAuthenticated

from orders.models import Order
from orders.serializers import (
    OrderSerializer,
    UpdateDeliveryLocationSerializer,
)
from authentication.permissions import IsDelivery
from .websocket import _broadcast_location

logger = logging.getLogger(__name__)


def _delivery_block_reason(order):
    if order.payment_status != "paid":
        method = (order.payment_method or "cod").upper()
        status_text = (order.payment_status or "pending").upper()
        return f"Cannot mark delivered while payment is {method} | {status_text}. Collect or confirm payment first."
    return None


class DeliveryOrdersView(generics.ListAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsDelivery]

    def get_queryset(self):
        return Order.objects.filter(assigned_delivery=self.request.user).order_by(
            "-created_at"
        )


class UpdateDeliveryLocationView(APIView):
    """Delivery person posts their current GPS coordinates for an active order."""

    permission_classes = [IsDelivery]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, assigned_delivery=request.user)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND
            )

        if order.status != "out_for_delivery":
            return Response(
                {"detail": "Location updates only allowed when out for delivery."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = UpdateDeliveryLocationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        if serializer.validated_data.get("heartbeat"):
            order.delivery_location_updated_at = timezone.now()
            order.save(update_fields=["delivery_location_updated_at"])
        else:
            order.delivery_latitude = serializer.validated_data["latitude"]
            order.delivery_longitude = serializer.validated_data["longitude"]
            order.delivery_location_updated_at = timezone.now()
            order.save(
                update_fields=[
                    "delivery_latitude",
                    "delivery_longitude",
                    "delivery_location_updated_at",
                ]
            )

        _broadcast_location(order)

        return Response({"detail": "Location updated."})


class GetDeliveryLocationView(APIView):
    """Customer polls for the delivery person's current GPS location."""

    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND
            )

        # RBAC Check: Only the placing customer, assigned driver, or admin can track the location
        if not (
            request.user == order.user
            or request.user == order.assigned_delivery
            or request.user.role == "admin"
        ):
            return Response(
                {"detail": "You do not have permission to view this order's location."},
                status=status.HTTP_403_FORBIDDEN,
            )

        if order.delivery_latitude is None:
            return Response({"available": False})

        return Response(
            {
                "available": True,
                "latitude": str(order.delivery_latitude),
                "longitude": str(order.delivery_longitude),
                "updated_at": order.delivery_location_updated_at,
            }
        )
