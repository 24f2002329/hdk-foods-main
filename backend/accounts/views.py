from django.db.models import Count, Q
from rest_framework import generics, status
from rest_framework.pagination import PageNumberPagination
from rest_framework.permissions import IsAuthenticated
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


class CustomerPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


class AddressListCreateView(generics.ListCreateAPIView):

    serializer_class = AddressSerializer

    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        return Address.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        is_first_address = not Address.objects.filter(user=self.request.user).exists()

        is_default = (
            serializer.validated_data.get("is_default", False) or is_first_address
        )

        if is_default:
            Address.objects.filter(user=self.request.user).update(is_default=False)

        serializer.save(user=self.request.user, is_default=is_default)


class AddressDetailView(generics.RetrieveUpdateDestroyAPIView):

    serializer_class = AddressSerializer

    permission_classes = [IsAuthenticated]

    def get_queryset(self):

        return Address.objects.filter(user=self.request.user)

    def perform_update(self, serializer):
        is_default = serializer.validated_data.get(
            "is_default", serializer.instance.is_default
        )

        if is_default:
            Address.objects.filter(user=self.request.user).exclude(
                pk=serializer.instance.pk
            ).update(is_default=False)

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
        return User.objects.filter(role="delivery").order_by(
            "-is_default_delivery", "name"
        )


class SetDefaultDeliveryView(APIView):
    """Mark one delivery user as the default. Admin only."""

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            user = User.objects.get(pk=pk, role="delivery")
        except User.DoesNotExist:
            return Response(
                {"detail": "Delivery user not found."}, status=status.HTTP_404_NOT_FOUND
            )

        # Clear existing default, then set this one.
        User.objects.filter(role="delivery", is_default_delivery=True).update(
            is_default_delivery=False
        )

        user.is_default_delivery = True
        user.save(update_fields=["is_default_delivery"])

        return Response(DeliveryStaffSerializer(user).data)


class SaveFCMTokenView(APIView):
    """Customer saves their FCM device token after login."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        token = request.data.get("fcm_token", "").strip()
        if not token:
            return Response(
                {"detail": "fcm_token is required."}, status=status.HTTP_400_BAD_REQUEST
            )
        request.user.fcm_token = token
        request.user.save(update_fields=["fcm_token"])
        return Response({"detail": "Token saved."})


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


# ── Customer management ────────────────────────────────────────────────────────


def _customer_to_dict(user, order_count=None):
    if order_count is None:
        from orders.models import Order

        order_count = Order.objects.filter(user=user).count()
    return {
        "id": user.id,
        "name": user.name,
        "phone_number": user.phone_number,
        "is_active": user.is_active,
        "created_at": user.created_at,
        "order_count": order_count,
        "loyalty_coins": getattr(user, "loyalty_coins", 0),
    }


class CustomerListView(APIView):
    """List all customers. Admin only. Supports ?search= and ?page="""

    permission_classes = [IsAdmin]
    pagination_class = CustomerPagination

    def get(self, request):
        search = request.query_params.get("search", "").strip()
        qs = User.objects.filter(role="customer").order_by("-created_at")
        if search:
            qs = qs.filter(
                Q(name__icontains=search) | Q(phone_number__icontains=search)
            )
        qs = qs.annotate(order_count=Count("order"))

        paginator = CustomerPagination()
        page = paginator.paginate_queryset(qs, request)
        data = [
            {
                "id": u.id,
                "name": u.name,
                "phone_number": u.phone_number,
                "is_active": u.is_active,
                "created_at": u.created_at,
                "order_count": u.order_count,
                "loyalty_coins": getattr(u, "loyalty_coins", 0),
            }
            for u in page
        ]
        return paginator.get_paginated_response(data)


class CustomerDetailView(APIView):
    """Customer detail with recent orders and addresses. Admin only."""

    permission_classes = [IsAdmin]

    def get(self, request, pk):
        try:
            user = User.objects.get(pk=pk, role="customer")
        except User.DoesNotExist:
            return Response(
                {"detail": "Customer not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        from orders.models import Order
        from orders.serializers import OrderSerializer

        recent_orders = Order.objects.filter(user=user).order_by("-created_at")[:10]
        addresses = Address.objects.filter(user=user)

        return Response(
            {
                "id": user.id,
                "name": user.name,
                "phone_number": user.phone_number,
                "is_active": user.is_active,
                "created_at": user.created_at,
                "order_count": Order.objects.filter(user=user).count(),
                "loyalty_coins": getattr(user, "loyalty_coins", 0),
                "recent_orders": OrderSerializer(recent_orders, many=True).data,
                "addresses": AddressSerializer(addresses, many=True).data,
            }
        )


class ToggleCustomerStatusView(APIView):
    """Block or unblock a customer. Admin only."""

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            user = User.objects.get(pk=pk, role="customer")
        except User.DoesNotExist:
            return Response(
                {"detail": "Customer not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        user.is_active = not user.is_active
        user.save(update_fields=["is_active"])
        return Response(_customer_to_dict(user))


class DeleteCustomerView(APIView):
    """Permanently delete a customer account. Admin only."""

    permission_classes = [IsAdmin]

    def delete(self, request, pk):
        try:
            user = User.objects.get(pk=pk, role="customer")
        except User.DoesNotExist:
            return Response(
                {"detail": "Customer not found."},
                status=status.HTTP_404_NOT_FOUND,
            )

        user.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


def normalize_phone_number(phone):
    phone = phone.strip()
    if not phone:
        return ""
    phone = "".join(c for c in phone if c.isdigit() or c == "+")
    if len(phone) == 10 and phone.isdigit():
        return f"+91{phone}"
    if len(phone) == 12 and phone.startswith("91"):
        return f"+{phone}"
    if phone.startswith("+"):
        return phone
    return phone


class AdminCustomerInfoView(APIView):
    """Admin fetches customer name and saved addresses by phone number."""

    permission_classes = [IsAdmin]

    def get(self, request):
        phone = request.query_params.get("phone", "").strip()
        if not phone:
            return Response(
                {"detail": "Phone parameter is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        normalized_phone = normalize_phone_number(phone)
        raw_10_digit = phone[-10:] if len(phone) >= 10 else phone

        user = User.objects.filter(
            Q(phone_number=phone)
            | Q(phone_number=normalized_phone)
            | Q(phone_number__endswith=raw_10_digit)
        ).first()

        if not user:
            return Response({"found": False})

        addresses = Address.objects.filter(user=user)
        addresses_data = []
        for addr in addresses:
            addresses_data.append(
                {
                    "id": addr.id,
                    "label": addr.label,
                    "house": addr.house,
                    "street": addr.street,
                    "landmark": addr.landmark,
                    "city": addr.city,
                    "pincode": addr.pincode,
                    "latitude": float(addr.latitude),
                    "longitude": float(addr.longitude),
                    "is_default": addr.is_default,
                }
            )

        return Response(
            {
                "found": True,
                "user_id": user.id,
                "name": user.name,
                "phone_number": user.phone_number,
                "addresses": addresses_data,
            }
        )


class CoinTransactionsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from orders.models import Order

        user = request.user

        # Query orders where coins were redeemed or earned
        orders = (
            Order.objects.filter(user=user)
            .filter(Q(coins_redeemed__gt=0) | Q(coins_earned__gt=0))
            .order_by("-created_at")
        )

        transactions = []
        for order in orders:
            # 1. Earned transaction (only if order is delivered)
            if order.coins_earned > 0 and order.status == "delivered":
                transactions.append(
                    {
                        "id": f"earn_{order.id}",
                        "order_id": order.id,
                        "order_number": order.order_number,
                        "amount": order.coins_earned,
                        "type": "earned",
                        "description": f"Earned from order {order.order_number}",
                        "created_at": (
                            order.updated_at.isoformat()
                            if order.updated_at
                            else order.created_at.isoformat()
                        ),
                    }
                )

            # 2. Redeemed transaction
            if order.coins_redeemed > 0:
                transactions.append(
                    {
                        "id": f"redeem_{order.id}",
                        "order_id": order.id,
                        "order_number": order.order_number,
                        "amount": -order.coins_redeemed,
                        "type": "redeemed",
                        "description": f"Redeemed on order {order.order_number}",
                        "created_at": order.created_at.isoformat(),
                    }
                )

                # 3. Refunded transaction (if order cancelled/rejected and coins returned)
                if order.status in ("cancelled", "rejected"):
                    transactions.append(
                        {
                            "id": f"refund_{order.id}",
                            "order_id": order.id,
                            "order_number": order.order_number,
                            "amount": order.coins_redeemed,
                            "type": "refunded",
                            "description": (
                                f"Refunded for cancelled order {order.order_number}"
                                if order.status == "cancelled"
                                else f"Refunded for rejected order {order.order_number}"
                            ),
                            "created_at": (
                                order.updated_at.isoformat()
                                if order.updated_at
                                else order.created_at.isoformat()
                            ),
                        }
                    )

        # Sort transactions by created_at descending
        transactions.sort(key=lambda t: t["created_at"], reverse=True)

        return Response(
            {"loyalty_coins": user.loyalty_coins, "transactions": transactions}
        )
