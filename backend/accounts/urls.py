from django.urls import path

from .views import (
    AddressListCreateView,
    AddressDetailView,
    CurrentUserView
)

urlpatterns = [

    path(
        "me/",
        CurrentUserView.as_view()
    ),

    path(
        "addresses/",
        AddressListCreateView.as_view()
    ),

    path(
        "addresses/<int:pk>/",
        AddressDetailView.as_view()
    ),
]