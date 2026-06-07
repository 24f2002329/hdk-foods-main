from django.urls import path

from .views import (
    AddressListCreateView,
    AddressDetailView
)

urlpatterns = [

    path(
        "addresses/",
        AddressListCreateView.as_view()
    ),

    path(
        "addresses/<int:pk>/",
        AddressDetailView.as_view()
    ),
]