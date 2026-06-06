from django.urls import path

from .views import (
    ConfirmOrderView,
    CreateOrderView,
    OrderListView,
    RejectOrderView,
    UpdateOrderStatusView
)

urlpatterns = [
    path(
        "",
        OrderListView.as_view()
    ),

    path(
        "create/",
        CreateOrderView.as_view()
    ),

    path(
        "<int:pk>/confirm/",
        ConfirmOrderView.as_view()
    ),

    path(
        "<int:pk>/reject/",
        RejectOrderView.as_view()
    ),

    path(
        "<int:pk>/status/",
        UpdateOrderStatusView.as_view()
    ),
]