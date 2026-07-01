import json
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from rest_framework_simplejwt.tokens import AccessToken
from asgiref.sync import sync_to_async


def _get_user(token_str):
    from django.contrib.auth import get_user_model
    from django.db import close_old_connections

    close_old_connections()
    User = get_user_model()
    try:
        token = AccessToken(token_str)
        return User.objects.get(id=token["user_id"])
    except Exception:
        return None
    finally:
        close_old_connections()


class OrderConsumer(AsyncJsonWebsocketConsumer):
    """
    WebSocket consumer for real-time order status updates.

    Connect patterns:
      ws://.../ws/orders/<order_id>/?token=<jwt>   – watch a single order
      ws://.../ws/admin/orders/?token=<jwt>         – admin watches all orders
      ws://.../ws/delivery/orders/?token=<jwt>      – delivery watches assigned
    """

    async def connect(self):
        query_string = self.scope.get("query_string", b"").decode()
        params = dict(p.split("=", 1) for p in query_string.split("&") if "=" in p)
        token_str = params.get("token", "")

        self.user = await sync_to_async(_get_user)(token_str)
        if self.user is None:
            await self.close(code=4001)
            return

        # Determine which groups to join based on URL route
        self.groups_joined = []
        url_route = self.scope.get("url_route", {})
        kwargs = url_route.get("kwargs", {})

        if "order_id" in kwargs:
            # Single-order watcher – customer, admin, or delivery
            order_id = kwargs["order_id"]
            group = f"order_{order_id}"
            self.groups_joined.append(group)

        elif self.scope["path"].startswith("/ws/admin/"):
            if not (hasattr(self.user, "role") and self.user.role == "admin"):
                await self.close(code=4003)
                return
            self.groups_joined.append("admin_orders")

        elif self.scope["path"].startswith("/ws/delivery/"):
            if not (
                hasattr(self.user, "role") and self.user.role in ("delivery", "admin")
            ):
                await self.close(code=4003)
                return
            self.groups_joined.append(f"delivery_{self.user.id}")

        for group in self.groups_joined:
            await self.channel_layer.group_add(group, self.channel_name)

        await self.accept()

    async def disconnect(self, close_code):
        for group in getattr(self, "groups_joined", []):
            await self.channel_layer.group_discard(group, self.channel_name)

    async def receive_json(self, content):
        pass

    # ── event handlers sent from Django views ─────────────────────────────────

    async def order_update(self, event):
        await self.send_json(event["data"])

    async def new_order(self, event):
        await self.send_json(event["data"])

    async def delivery_update(self, event):
        await self.send_json(event["data"])

    async def location_update(self, event):
        await self.send_json(event["data"])
