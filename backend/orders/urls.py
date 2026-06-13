from django.urls import path

from .views import (
    AdminDashboardView,
    AssignDeliveryView,
    CashfreeWebhookView,
    ConfirmOrderView,
    CreateOrderView,
    DeliveryOrdersView,
    MyOrdersView,
    OrderDetailView,
    OrderListView,
    PendingOrdersView,
    RejectOrderView,
    SelectPaymentView,
    UpdateOrderStatusView,
    VerifyPaymentView
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
        "my-orders/",
        MyOrdersView.as_view()
    ),

    path(
        "<int:pk>/",
        OrderDetailView.as_view()
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

    path(
        "<int:pk>/select-payment/",
        SelectPaymentView.as_view()
    ),

    path(
        "<int:pk>/verify-payment/",
        VerifyPaymentView.as_view()
    ),

    path(
        "<int:pk>/assign-delivery/",
        AssignDeliveryView.as_view()
    ),

    path(
        "delivery/",
        DeliveryOrdersView.as_view()
    ),

    path(
        "pending/",
        PendingOrdersView.as_view()
    ),

    path(
        "admin/dashboard/",
        AdminDashboardView.as_view()
    ),

    path(
        "webhook/cashfree/",
        CashfreeWebhookView.as_view()
    ),
]