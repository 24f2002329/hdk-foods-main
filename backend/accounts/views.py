from rest_framework import generics
from rest_framework.permissions import (
    IsAuthenticated
)
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Address, User
from .serializers import (
    AddressSerializer,
    UserSerializer
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
        is_first_address = not Address.objects.filter(
            user=self.request.user
        ).exists()

        is_default = serializer.validated_data.get(
            "is_default",
            False
        ) or is_first_address

        if is_default:
            Address.objects.filter(
                user=self.request.user
            ).update(
                is_default=False
            )

        serializer.save(
            user=self.request.user,
            is_default=is_default
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

    def perform_update(
        self,
        serializer
    ):
        is_default = serializer.validated_data.get(
            "is_default",
            serializer.instance.is_default
        )

        if is_default:
            Address.objects.filter(
                user=self.request.user
            ).exclude(
                pk=serializer.instance.pk
            ).update(
                is_default=False
            )

        serializer.save()


class CurrentUserView(APIView):
    """Return the current authenticated user's profile."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)
