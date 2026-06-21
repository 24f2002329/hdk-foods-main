from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r"^ws/orders/(?P<order_id>\d+)/$", consumers.OrderConsumer.as_asgi()),
    re_path(r"^ws/admin/orders/$", consumers.OrderConsumer.as_asgi()),
    re_path(r"^ws/delivery/orders/$", consumers.OrderConsumer.as_asgi()),
]
