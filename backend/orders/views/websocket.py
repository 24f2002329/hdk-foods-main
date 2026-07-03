import logging
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from authentication.firebase import send_push
from authentication.utils import sanitize_text
from orders.models import Order, OrderMessage
from orders.serializers import OrderSerializer, OrderMessageSerializer

logger = logging.getLogger(__name__)


def _broadcast_order(order, event_type="order_update"):
    """Send a real-time update to all WebSocket clients watching this order."""
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    data = OrderSerializer(order).data
    payload = {"type": event_type, "data": {"type": event_type, **data}}
    # Notify the per-order group (customer/delivery/admin watching this order)
    async_to_sync(channel_layer.group_send)(f"order_{order.id}", payload)
    # Notify the admin dashboard group
    async_to_sync(channel_layer.group_send)(
        "admin_orders",
        {"type": "order_update", "data": {"type": "order_update", **data}},
    )
    # Notify the assigned delivery partner if any
    if order.assigned_delivery_id:
        async_to_sync(channel_layer.group_send)(
            f"delivery_{order.assigned_delivery_id}",
            {"type": "delivery_update", "data": {"type": "delivery_update", **data}},
        )


def _broadcast_location(order):
    """Send a minified location update to all WebSocket clients watching this order."""
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    # Compact structure: [latitude, longitude, speed, bearing, driver_id]
    lat = float(order.delivery_latitude) if order.delivery_latitude else 0.0
    lng = float(order.delivery_longitude) if order.delivery_longitude else 0.0
    driver_id = (
        f"drv_{order.assigned_delivery_id}" if order.assigned_delivery_id else ""
    )
    compact_data = [lat, lng, 0.0, 0, driver_id]
    payload = {
        "type": "location_update",
        "data": {"type": "location_update", "data": compact_data},
    }
    # Notify the per-order group (customer/delivery/admin watching this order)
    async_to_sync(channel_layer.group_send)(f"order_{order.id}", payload)
    # Notify the admin dashboard group
    async_to_sync(channel_layer.group_send)("admin_orders", payload)
    # Notify the assigned delivery partner if any
    if order.assigned_delivery_id:
        async_to_sync(channel_layer.group_send)(
            f"delivery_{order.assigned_delivery_id}", payload
        )


class OrderMessageListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, order_id):
        try:
            order = Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            return Response(
                {"error": "Order not found"}, status=status.HTTP_404_NOT_FOUND
            )

        if (
            request.user.role != "admin"
            and order.user != request.user
            and order.assigned_delivery != request.user
        ):
            return Response(
                {"error": "Unauthorized access"}, status=status.HTTP_403_FORBIDDEN
            )

        messages = OrderMessage.objects.filter(order=order).order_by("created_at")
        serializer = OrderMessageSerializer(messages, many=True)
        return Response(serializer.data)

    def post(self, request, order_id):
        try:
            order = Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            return Response(
                {"error": "Order not found"}, status=status.HTTP_404_NOT_FOUND
            )

        if (
            request.user.role != "admin"
            and order.user != request.user
            and order.assigned_delivery != request.user
        ):
            return Response(
                {"error": "Unauthorized access"}, status=status.HTTP_403_FORBIDDEN
            )

        message_text = sanitize_text(request.data.get("message", "").strip())
        if not message_text:
            return Response(
                {"error": "Message cannot be empty"}, status=status.HTTP_400_BAD_REQUEST
            )

        is_admin = request.user.role == "admin"
        msg = OrderMessage.objects.create(
            order=order, sender=request.user, message=message_text, is_admin=is_admin
        )

        try:
            channel_layer = get_channel_layer()
            if channel_layer is not None:
                data = OrderMessageSerializer(msg).data
                payload = {
                    "type": "order_update",
                    "data": {"type": "chat_message", "message": data},
                }
                async_to_sync(channel_layer.group_send)(f"order_{order.id}", payload)
        except Exception as e:
            logger.warning(f"Failed to broadcast websocket chat message: {e}")

        try:
            if is_admin:
                send_push(
                    order.user,
                    "Message from Kitchen 💬",
                    message_text,
                    data={
                        "type": "chat",
                        "order_id": order.id,
                        "order_number": order.order_number,
                    },
                )
        except Exception as e:
            logger.warning(f"Could not send chat push notification: {e}")

        return Response(
            OrderMessageSerializer(msg).data, status=status.HTTP_201_CREATED
        )
