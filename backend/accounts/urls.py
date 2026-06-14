from django.urls import path

from .views import (
    AddressListCreateView,
    AddressDetailView,
    CreateDeliveryStaffView,
    CurrentUserView,
    DeliveryStaffListView,
    SaveFCMTokenView,
    SetDefaultDeliveryView,
)

urlpatterns = [
    path("me/", CurrentUserView.as_view()),
    path("addresses/", AddressListCreateView.as_view()),
    path("addresses/<int:pk>/", AddressDetailView.as_view()),
    path("delivery-staff/", DeliveryStaffListView.as_view()),
    path("delivery-staff/create/", CreateDeliveryStaffView.as_view()),
    path("delivery-staff/<int:pk>/set-default/", SetDefaultDeliveryView.as_view()),
    path("fcm-token/", SaveFCMTokenView.as_view()),
]
