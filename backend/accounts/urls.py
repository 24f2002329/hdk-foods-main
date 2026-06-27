from django.urls import path

from .views import (
    AddressListCreateView,
    AddressDetailView,
    CreateDeliveryStaffView,
    CurrentUserView,
    CustomerDetailView,
    CustomerListView,
    DeleteCustomerView,
    DeliveryStaffListView,
    SaveFCMTokenView,
    SetDefaultDeliveryView,
    ToggleCustomerStatusView,
    AdminCustomerInfoView,
)

urlpatterns = [
    path("me/", CurrentUserView.as_view()),
    path("addresses/", AddressListCreateView.as_view()),
    path("addresses/<int:pk>/", AddressDetailView.as_view()),
    path("delivery-staff/", DeliveryStaffListView.as_view()),
    path("delivery-staff/create/", CreateDeliveryStaffView.as_view()),
    path("delivery-staff/<int:pk>/set-default/", SetDefaultDeliveryView.as_view()),
    path("fcm-token/", SaveFCMTokenView.as_view()),
    path("customers/", CustomerListView.as_view()),
    path("customers/<int:pk>/", CustomerDetailView.as_view()),
    path("customers/<int:pk>/toggle-status/", ToggleCustomerStatusView.as_view()),
    path("customers/<int:pk>/delete/", DeleteCustomerView.as_view()),
    path("admin/customer-info/", AdminCustomerInfoView.as_view()),
]
