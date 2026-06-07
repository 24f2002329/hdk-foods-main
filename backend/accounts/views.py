from django.shortcuts import render

# Create your views here.
from rest_framework import generics
from rest_framework.permissions import (
    IsAuthenticated
)

from .models import Address
from .serializers import (
    AddressSerializer
)


class AddressListCreateView(generics.ListCreateAPIView):

    serializer_class = (
        AddressSerializer
    )

    permission_classes = [
        IsAuthenticated
    ]

    def get_queryset(self):

        return Address.objects.filter(
            user=self.request.user
        )

    def perform_create(
        self,
        serializer
    ):

        serializer.save(
            user=self.request.user
        )



class AddressDetailView(generics.RetrieveUpdateDestroyAPIView):

    serializer_class = (
        AddressSerializer
    )

    permission_classes = [
        IsAuthenticated
    ]

    def get_queryset(self):

        return Address.objects.filter(
            user=self.request.user
        )