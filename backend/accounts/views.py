from rest_framework import generics, status
from rest_framework.permissions import (
    IsAuthenticated
)
from rest_framework.response import Response
from rest_framework.views import APIView

from authentication.permissions import IsAdmin
from .models import Address, User
from .serializers import (
    AddressSerializer,
    CreateDeliveryStaffSerializer,
    DeliveryStaffSerializer,
    UserSerializer,
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
    """Return or update the current authenticated user's profile."""

    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user)
        return Response(serializer.data)

    def patch(self, request):
        serializer = UserSerializer(request.user, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class DeliveryStaffListView(generics.ListAPIView):
    """List all delivery users. Admin only."""

    serializer_class = DeliveryStaffSerializer
    permission_classes = [IsAdmin]

    def get_queryset(self):
        return User.objects.filter(
            role="delivery"
        ).order_by("-is_default_delivery", "name")


class SetDefaultDeliveryView(APIView):
    """Mark one delivery user as the default. Admin only."""

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            user = User.objects.get(pk=pk, role="delivery")
        except User.DoesNotExist:
            return Response(
                {"detail": "Delivery user not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        # Clear existing default, then set this one.
        User.objects.filter(
            role="delivery",
            is_default_delivery=True
        ).update(is_default_delivery=False)

        user.is_default_delivery = True
        user.save(update_fields=["is_default_delivery"])

        return Response(DeliveryStaffSerializer(user).data)


class CreateDeliveryStaffView(APIView):
    """Admin creates a new delivery staff account."""

    permission_classes = [IsAdmin]

    def post(self, request):
        serializer = CreateDeliveryStaffSerializer(data=request.data)
        if serializer.is_valid():
            user = serializer.save()
            return Response(
                DeliveryStaffSerializer(user).data,
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
