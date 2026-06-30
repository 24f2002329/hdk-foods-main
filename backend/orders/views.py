# from django.shortcuts import render

# Create your views here.

from decimal import Decimal
from rest_framework import status, generics
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.models import Address, User
from authentication.permissions import (
    IsAdmin,
    IsDelivery
)
from products.models import Product

from authentication.permissions import IsCustomer
from authentication.firebase import send_push, send_push_to_role
from .models import Coupon, Order, OrderItem, OrderReview, ProductReview
from .serializers import (
    AcknowledgeChangesSerializer,
    AdminPaymentMethodSerializer,
    ApplyDiscountSerializer,
    AssignDeliverySerializer,
    ConfirmOrderSerializer,
    CouponSerializer,
    CouponWriteSerializer,
    OrderCreateSerializer,
    OrderSerializer,
    RejectOrderSerializer,
    SelectPaymentSerializer,
    UpdateDeliveryLocationSerializer,
    UpdateStatusSerializer,
    OrderReviewSerializer,
    ProductReviewSerializer
)

from django.utils import timezone
from datetime import timedelta
from threading import Timer

from django.db.models import Sum, Count, F, Avg, Q
from django.db.models.functions import TruncDate, ExtractHour


def _delivery_block_reason(order):
    if order.payment_status != "paid":
        method = (order.payment_method or "cod").upper()
        status_text = (order.payment_status or "pending").upper()
        return f"Cannot mark delivered while payment is {method} | {status_text}. Collect or confirm payment first."
    return None


from rest_framework.permissions import IsAuthenticated, AllowAny
from rest_framework.pagination import PageNumberPagination
from rest_framework.parsers import MultiPartParser

from django.conf import settings
from django.views.decorators.csrf import csrf_exempt
from django.utils.decorators import method_decorator

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

import uuid
import requests
import logging
import hmac
import hashlib

logger = logging.getLogger(__name__)


def _send_pending_online_payment_reminder(order_id):
    try:
        order = Order.objects.select_related("user").get(pk=order_id)
    except Order.DoesNotExist:
        return

    if (
        order.payment_method != "online"
        or order.payment_status != "pending"
        or order.status in ("delivered", "cancelled", "rejected")
    ):
        return

    send_push(
        order.user,
        "Complete payment",
        f"Your payment for order #{order.order_number} is still pending. Tap to complete it.",
        {"order_id": str(order.id), "type": "payment_pending"},
    )


def _schedule_pending_online_payment_reminder(order_id):
    reminder = Timer(
        300,
        _send_pending_online_payment_reminder,
        args=(order_id,),
    )
    reminder.daemon = True
    reminder.start()


def _broadcast_order(order, event_type="order_update"):
    """Send a real-time update to all WebSocket clients watching this order."""
    channel_layer = get_channel_layer()
    if channel_layer is None:
        return
    data = OrderSerializer(order).data
    payload = {"type": event_type, "data": {"type": event_type, **data}}
    # Notify the per-order group (customer/delivery/admin watching this order)
    async_to_sync(channel_layer.group_send)(f"order_{order.id}", payload)
    # Notify the admin dashboard group
    async_to_sync(channel_layer.group_send)(
        "admin_orders",
        {"type": "order_update", "data": {"type": "order_update", **data}},
    )
    # Notify the assigned delivery partner if any
    if order.assigned_delivery_id:
        async_to_sync(channel_layer.group_send)(
            f"delivery_{order.assigned_delivery_id}",
            {"type": "delivery_update", "data": {"type": "delivery_update", **data}},
        )



class CreateOrderView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    def post(self, request):
        from app_config.models import SiteConfig
        config = SiteConfig.get()
        if not config.is_currently_open():
            return Response(
                {"detail": config.store_closed_msg or "The kitchen is closed right now."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = OrderCreateSerializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        data = serializer.validated_data

        address = Address.objects.get(
            id=data["address_id"],
            user=request.user
        )

        total_amount = Decimal("0.00")

        # Validate coupon early so we don't create an order if it's invalid
        coupon_code = data.get("coupon_code", "").strip()
        coupon = None
        if coupon_code:
            try:
                coupon = Coupon.objects.get(code__iexact=coupon_code, is_active=True)
            except Coupon.DoesNotExist:
                return Response(
                    {"detail": "Invalid or expired coupon code."},
                    status=status.HTTP_400_BAD_REQUEST,
                )

        order = Order.objects.create(
            user=address.user,
            address=address,
            payment_method=data.get(
                "payment_method"
            ) or "cod",
            delivery_notes=data.get(
                "delivery_notes",
                ""
            ),
            total_amount=0
        )

        for item in data["items"]:

            product = Product.objects.get(
                id=item["product_id"]
            )

            quantity = item["quantity"]

            price = product.price

            total_amount += (
                price * quantity
            )

            OrderItem.objects.create(
                order=order,
                product=product,
                quantity=quantity,
                price=price
            )

        order.total_amount = total_amount

        # Apply coupon discount
        if coupon:
            now = timezone.now()
            if coupon.valid_from and now < coupon.valid_from:
                order.delete()
                return Response(
                    {"detail": "Coupon is not yet valid."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if coupon.valid_until and now > coupon.valid_until:
                order.delete()
                return Response(
                    {"detail": "Coupon has expired."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if coupon.usage_limit and coupon.usage_count >= coupon.usage_limit:
                order.delete()
                return Response(
                    {"detail": "Coupon usage limit reached."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if total_amount < coupon.min_order_amount:
                order.delete()
                return Response(
                    {"detail": f"Minimum order amount for this coupon is ₹{coupon.min_order_amount}."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            discount = coupon.compute_discount(total_amount)
            order.discount_amount = discount
            order.discount_reason = f"Coupon: {coupon.code}"
            order.original_total = total_amount
            order.total_amount = total_amount - discount
            Coupon.objects.filter(pk=coupon.pk).update(usage_count=coupon.usage_count + 1)

        # Apply loyalty coins redemption
        redeem_coins = bool(request.data.get("redeem_coins", False))
        if redeem_coins:
            user = request.user
            available_coins = getattr(user, 'loyalty_coins', 0)
            if available_coins > 0:
                redeemed = min(available_coins, int(order.total_amount))
                if redeemed > 0:
                    order.coins_redeemed = redeemed
                    order.total_amount = order.total_amount - Decimal(str(redeemed))
                    user.loyalty_coins = available_coins - redeemed
                    user.save(update_fields=['loyalty_coins'])

        order.save()

        send_push_to_role(
            'admin',
            'New Order 🛍️',
            f'Order #{order.order_number} is waiting for review.',
            {'order_id': str(order.id)},
        )

        _broadcast_order(order, "new_order")

        return Response(
            OrderSerializer(order).data,
            status=status.HTTP_201_CREATED
        )



class SelectPaymentView(APIView):
    """Customer selects payment method after the order is confirmed.

    cod    -> mark method, order proceeds straight to tracking.
    online -> create a Cashfree order and return the checkout params.
    """

    permission_classes = [
        IsAuthenticated
    ]

    def post(self, request, pk):

        try:
            order = Order.objects.get(
                pk=pk,
                user=request.user
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        if order.status not in ["confirmed", "preparing", "out_for_delivery"]:
            return Response(
                {
                    "detail":
                        "Order must be confirmed, preparing, or out for delivery "
                        "before payment."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        if order.payment_status == "paid":
            return Response(
                {"detail": "Order already paid."},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = SelectPaymentSerializer(
            data=request.data
        )

        serializer.is_valid(
            raise_exception=True
        )

        method = serializer.validated_data[
            "payment_method"
        ]

        if method == "cod":
            order.payment_method = "cod"
            order.payment_status = "pending"
            order.save(
                update_fields=[
                    "payment_method",
                    "payment_status",
                    "updated_at"
                ]
            )

            return Response(
                {
                    "payment_method": "cod",
                    "order":
                        OrderSerializer(order).data
                }
            )

        # online -> Cashfree
        if not settings.CASHFREE_APP_ID or \
                not settings.CASHFREE_SECRET_KEY:
            return Response(
                {
                    "detail":
                        "Online payment is not "
                        "configured."
                },
                status=status.HTTP_503_SERVICE_UNAVAILABLE
            )

        # Cashfree expects the amount in rupees (not paise) and a globally
        # unique order id. A failed attempt leaves its order behind on
        # Cashfree, so each attempt gets a fresh id derived from our
        # order_number to avoid an "order_already_exists" collision on retry.
        cf_order_id = (
            f"{order.order_number}_"
            f"{uuid.uuid4().hex[:10]}"
        )

        logger.info(
            f"Creating Cashfree order: cf_order_id={cf_order_id}, "
            f"amount={order.total_amount}, user_id={request.user.id}"
        )

        try:
            cf_response = requests.post(
                f"{settings.CASHFREE_BASE_URL}/orders",
                headers={
                    "x-client-id":
                        settings.CASHFREE_APP_ID,
                    "x-client-secret":
                        settings.CASHFREE_SECRET_KEY,
                    "x-api-version":
                        settings.CASHFREE_API_VERSION,
                    "Content-Type":
                        "application/json",
                },
                json={
                    "order_id": cf_order_id,
                    "order_amount": float(
                        order.total_amount
                    ),
                    "order_currency": "INR",
                    "customer_details": {
                        "customer_id":
                            str(request.user.id),
                        "customer_phone":
                            request.user.phone_number,
                        "customer_name":
                            request.user.name or "Customer",
                    },
                },
                timeout=15
            )
        except requests.RequestException:
            return Response(
                {
                    "detail":
                        "Could not reach payment "
                        "gateway."
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        if cf_response.status_code not in (200, 201):
            return Response(
                {
                    "detail":
                        "Payment gateway error.",
                    "gateway":
                        cf_response.text
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        cf_order = cf_response.json()

        order.payment_method = "online"
        order.cashfree_order_id = cf_order_id
        order.payment_session_id = cf_order[
            "payment_session_id"
        ]
        # A new attempt supersedes any prior failed one.
        if order.payment_status == "failed":
            order.payment_status = "pending"
        order.save(
            update_fields=[
                "payment_method",
                "cashfree_order_id",
                "payment_session_id",
                "payment_status",
                "updated_at"
            ]
        )

        return Response(
            {
                "payment_method": "online",
                "payment_session_id":
                    cf_order["payment_session_id"],
                "cf_order_id":
                    cf_order_id,
                "environment":
                    settings.CASHFREE_ENV,
                "order":
                    OrderSerializer(order).data
            }
        )


class VerifyPaymentView(APIView):
    """Confirm payment with Cashfree and mark the order paid.

    Cashfree does not hand the client a signature to verify. Instead we
    fetch the order's status from Cashfree (server-to-server) and trust
    only ``order_status == "PAID"``.
    """

    permission_classes = [
        IsAuthenticated
    ]

    def post(self, request, pk):

        try:
            order = Order.objects.get(
                pk=pk,
                user=request.user
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        # No online attempt has been started for this order yet.
        if not order.cashfree_order_id:
            return Response(
                {
                    "payment_status":
                        order.payment_status,
                    "order":
                        OrderSerializer(order).data
                }
            )

        try:
            cf_response = requests.get(
                f"{settings.CASHFREE_BASE_URL}"
                f"/orders/{order.cashfree_order_id}",
                headers={
                    "x-client-id":
                        settings.CASHFREE_APP_ID,
                    "x-client-secret":
                        settings.CASHFREE_SECRET_KEY,
                    "x-api-version":
                        settings.CASHFREE_API_VERSION,
                },
                timeout=15
            )
        except requests.RequestException:
            return Response(
                {
                    "detail":
                        "Could not reach payment "
                        "gateway."
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        if cf_response.status_code != 200:
            return Response(
                {
                    "detail":
                        "Payment gateway error.",
                    "gateway":
                        cf_response.text
                },
                status=status.HTTP_502_BAD_GATEWAY
            )

        cf_order = cf_response.json()
        order_status = cf_order.get(
            "order_status"
        )

        logger.info(
            f"Verified Cashfree payment: order_id={order.id}, "
            f"cf_order_id={order.cashfree_order_id}, status={order_status}"
        )

        # PAID                 -> success
        # EXPIRED/TERMINATED   -> terminal failure
        # ACTIVE (and others)  -> still awaiting payment; leave pending so
        #                         this endpoint is safe to poll repeatedly.
        if order_status == "PAID":
            order.payment_status = "paid"
            order.payment_id = str(
                cf_order.get("cf_order_id", "")
            )
            order.save(
                update_fields=[
                    "payment_status",
                    "payment_id",
                    "updated_at"
                ]
            )

            return Response(
                {
                    "payment_status": "paid",
                    "order":
                        OrderSerializer(order).data
                }
            )

        if order_status in ("EXPIRED", "TERMINATED"):
            order.payment_status = "failed"
            order.save(
                update_fields=[
                    "payment_status",
                    "updated_at"
                ]
            )

        return Response(
            {
                "payment_status":
                    order.payment_status,
                "order_status":
                    order_status,
                "order":
                    OrderSerializer(order).data
            }
        )


class DriverInitiatePaymentView(APIView):
    """Driver requests/generates a native UPI Intent QR for COD to Online conversion."""
    permission_classes = [IsAdmin | IsDelivery]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if order.payment_status == "paid":
            return Response({
                "detail": "Order already paid.",
                "upi_uri": "",
                "amount": float(order.total_amount),
                "order_number": order.order_number,
                "payment_status": "paid"
            }, status=status.HTTP_200_OK)

        from app_config.models import SiteConfig
        import urllib.parse
        config = SiteConfig.get()
        merchant_upi_id = config.merchant_upi_id or "hdkfoods@axisbank"
        
        # Clean amount representation
        amount_str = f"{order.total_amount:.2f}".rstrip('0').rstrip('.')

        # Construct dynamic upi://pay Intent URI
        params = {
            "pa": merchant_upi_id,
            "pn": "HDK Foods",
            "am": amount_str,
            "cu": "INR",
            "tn": f"Order {order.order_number}"
        }
        upi_uri = f"upi://pay?{urllib.parse.urlencode(params, quote_via=urllib.parse.quote)}"

        # Set payment method to online for tracking
        order.payment_method = "online"
        order.save(update_fields=["payment_method", "updated_at"])

        return Response({
            "upi_uri": upi_uri,
            "amount": float(order.total_amount),
            "order_number": order.order_number,
            "payment_status": order.payment_status
        })


class DriverVerifyPaymentView(APIView):
    """Driver marks payment as completed directly (bypassing UTR validation)."""
    permission_classes = [IsAdmin | IsDelivery]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        # Mark order as paid directly
        order.payment_status = "paid"
        order.payment_id = f"verified_by_driver_{timezone.now().strftime('%Y%m%d%H%M%S')}"
        order.payment_method = "online"
        order.save(update_fields=["payment_status", "payment_id", "payment_method", "updated_at"])

        return Response({
            "payment_status": "paid",
            "payment_id": order.payment_id,
            "order": OrderSerializer(order).data
        })


class OrderPagination(PageNumberPagination):
    page_size = 20
    page_size_query_param = "page_size"
    max_page_size = 100


class OrderListView(generics.ListAPIView):

    queryset = Order.objects.all().order_by(
        "-created_at"
    )

    serializer_class = OrderSerializer
    permission_classes = [IsAdmin]
    pagination_class = OrderPagination



class MyOrdersView(generics.ListAPIView):
    serializer_class = OrderSerializer
    pagination_class = OrderPagination

    permission_classes = [
        IsAuthenticated
    ]

    def get_queryset(self):
        return Order.objects.filter(
            user=self.request.user
        ).order_by(
            "-created_at"
        )


class OrderDetailView(generics.RetrieveAPIView):
    serializer_class = OrderSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if hasattr(user, 'role') and user.role in ('admin', 'delivery'):
            return Order.objects.all()
        return Order.objects.filter(user=user)
    


class ConfirmOrderView(APIView):

    permission_classes = [
        IsAdmin
    ]

    def patch(self, request, pk):

        try:
            order = Order.objects.get(
                pk=pk
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = (
            ConfirmOrderSerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        prep_time = serializer.validated_data[
            "estimated_preparation_time"
        ]

        order.status = "confirmed"

        order.confirmed_at = (
            timezone.now()
        )

        order.estimated_preparation_time = (
            prep_time
        )

        order.estimated_delivery_time = (
            timezone.now()
            + timedelta(
                minutes=prep_time + 15
            )
        )

        order.confirmed_by = request.user
        order.save()

        send_push(
            order.user,
            "Order Confirmed ✅",
            f"Your order #{order.order_number} is confirmed! Ready in ~{prep_time} mins.",
            {"order_id": str(order.id), "type": "order"},
        )

        if order.payment_method == "online" and order.payment_status == "pending":
            _schedule_pending_online_payment_reminder(order.id)

        _broadcast_order(order)

        return Response(
            OrderSerializer(order).data
        )


class RejectOrderView(APIView):

    permission_classes = [
        IsAdmin
    ]
    
    def patch(self, request, pk):

        try:
            order = Order.objects.get(
                pk=pk
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = (
            RejectOrderSerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        order.status = "rejected"

        order.rejection_reason = (
            serializer.validated_data[
                "reason"
            ]
        )

        order.save()

        send_push(
            order.user,
            "Order Rejected ❌",
            f"Order #{order.order_number} was rejected. Sorry for the inconvenience.",
            {"order_id": str(order.id), "type": "order"},
        )

        _broadcast_order(order)

        return Response(
            OrderSerializer(order).data
        )




class UpdateOrderStatusView(APIView):

    permission_classes = [
        IsAuthenticated
    ]

    def patch(self, request, pk):

        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = UpdateStatusSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_status = serializer.validated_data["status"]

        user = request.user

        # Delivery staff: may only mark their own assigned order as delivered
        if hasattr(user, 'role') and user.role == 'delivery':
            if new_status != 'delivered':
                return Response(
                    {"detail": "Delivery staff can only mark orders as delivered."},
                    status=status.HTTP_403_FORBIDDEN
                )
            if order.assigned_delivery_id != user.id:
                return Response(
                    {"detail": "You are not assigned to this order."},
                    status=status.HTTP_403_FORBIDDEN
                )
        elif not (hasattr(user, 'role') and user.role == 'admin'):
            return Response(
                {"detail": "You do not have permission to perform this action."},
                status=status.HTTP_403_FORBIDDEN
            )

        if new_status == 'delivered' and order.status != 'delivered':
            block_reason = _delivery_block_reason(order)
            if block_reason:
                return Response(
                    {"detail": block_reason},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            from app_config.models import SiteConfig
            percentage = SiteConfig.get().loyalty_coins_percentage
            earned = int((order.total_amount * percentage) // 100)
            if earned > 0:
                customer = order.user
                customer.loyalty_coins = getattr(customer, 'loyalty_coins', 0) + earned
                customer.save(update_fields=['loyalty_coins'])
                order.coins_earned = earned

        order.status = new_status
        order.save()

        _push_map = {
            "preparing": ("Kitchen is preparing your order 👨‍🍳", "Your food is being freshly prepared!"),
            "out_for_delivery": ("On the way! 🛵", f"Order #{order.order_number} is out for delivery."),
            "delivered": ("Order Delivered! 🎉", "Rate your food and share your feedback ⭐"),
        }
        if new_status in _push_map:
            title, body = _push_map[new_status]
            send_push(order.user, title, body, {"order_id": str(order.id), "type": "order"})

        _broadcast_order(order)

        return Response(
            OrderSerializer(order).data
        )



class AssignDeliveryView(APIView):

    permission_classes = [
        IsAdmin
    ]

    def patch(
        self,
        request,
        pk
    ):

        try:
            order = Order.objects.get(
                pk=pk
            )
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = (
            AssignDeliverySerializer(
                data=request.data
            )
        )

        serializer.is_valid(
            raise_exception=True
        )

        try:
            delivery_user = User.objects.get(
                id=serializer.validated_data[
                    "delivery_user_id"
                ],
                role="delivery"
            )
        except User.DoesNotExist:
            return Response(
                {
                    "detail":
                        "Delivery user not found."
                },
                status=status.HTTP_404_NOT_FOUND
            )

        order.assigned_delivery = delivery_user
        order.save()

        send_push(
            delivery_user,
            "New Delivery Assigned 🛵",
            f"Order #{order.order_number} has been assigned to you.",
            {"order_id": str(order.id), "type": "order"},
        )

        return Response(
            OrderSerializer(order).data
        )
    

class DeliveryOrdersView(generics.ListAPIView):

    serializer_class = (
        OrderSerializer
    )

    permission_classes = [
        IsDelivery
    ]

    def get_queryset(self):

        return Order.objects.filter(
            assigned_delivery=
            self.request.user
        ).order_by(
            "-created_at"
        )


class PendingOrdersView(generics.ListAPIView):

    serializer_class = (
        OrderSerializer
    )

    permission_classes = [
        IsAdmin
    ]

    def get_queryset(self):

        return Order.objects.filter(
            status=
            "pending_confirmation"
        ).order_by(
            "created_at"
        )






class AdminDashboardView(APIView):

    permission_classes = [IsAdmin]

    def get(self, request):
        period = request.query_params.get("period", "today")
        today = timezone.now().date()

        if period == "7d":
            start_date = today - timedelta(days=6)
        elif period == "30d":
            start_date = today - timedelta(days=29)
        elif period == "3m":
            start_date = today - timedelta(days=89)
        elif period == "year":
            start_date = today.replace(month=1, day=1)
        else:  # "today"
            period = "today"
            start_date = today

        period_qs = Order.objects.filter(
            created_at__date__gte=start_date
        )

        total_orders = period_qs.count()

        revenue = (
            period_qs.filter(payment_status="paid")
            .aggregate(total=Sum("total_amount"))["total"]
            or 0
        )

        delivered_count = period_qs.filter(
            status="delivered"
        ).count()

        # Extra stats
        cancelled_count = period_qs.filter(status="cancelled").count()
        rejected_count = period_qs.filter(status="rejected").count()

        aov = 0
        if delivered_count > 0:
            aov = round(float(revenue) / delivered_count, 2)

        # Reviews stats
        reviews_qs = OrderReview.objects.filter(created_at__date__gte=start_date)
        total_reviews = reviews_qs.count()
        avg_rating = reviews_qs.aggregate(avg=Avg("rating"))["avg"] or 0
        avg_rating = round(float(avg_rating), 1)

        # Top 5 products sold in this period
        top_selling = (
            OrderItem.objects.filter(order__created_at__date__gte=start_date)
            .values("product__name")
            .annotate(qty=Sum("quantity"), rev=Sum(F("price") * F("quantity")))
            .order_by("-qty")[:5]
        )
        top_products = [
            {
                "name": item["product__name"],
                "quantity": item["qty"],
                "revenue": float(item["rev"] or 0),
            }
            for item in top_selling
        ]

        # Hourly distribution of orders in this period (to identify Peak Times)
        hourly_dist = (
            period_qs
            .annotate(hour=ExtractHour("created_at"))
            .values("hour")
            .annotate(count=Count("id"))
            .order_by("hour")
        )
        hourly_data = {h["hour"]: h["count"] for h in hourly_dist}
        hourly_list = [{"hour": h, "count": hourly_data.get(h, 0)} for h in range(24)]

        # Always-live counts — current queue state, not date-filtered
        pending_orders = Order.objects.filter(
            status="pending_confirmation"
        ).count()

        active_deliveries = Order.objects.filter(
            status="out_for_delivery"
        ).count()

        in_progress = Order.objects.filter(
            status__in=["confirmed", "preparing"]
        ).count()

        return Response({
            "period": period,
            "start_date": str(start_date),
            "total_orders": total_orders,
            "revenue": float(revenue),
            "delivered_count": delivered_count,
            "pending_orders": pending_orders,
            "active_deliveries": active_deliveries,
            "in_progress": in_progress,
            "cancelled_count": cancelled_count,
            "rejected_count": rejected_count,
            "average_order_value": aov,
            "total_reviews": total_reviews,
            "average_rating": avg_rating,
            "top_products": top_products,
            "hourly_distribution": hourly_list,
        })


class DailyAnalyticsView(APIView):
    """Return per-day order count and revenue for the last N days (default 30)."""

    permission_classes = [IsAdmin]

    def get(self, request):
        days = int(request.query_params.get("days", 30))
        days = max(1, min(days, 365))
        start_date = timezone.now().date() - timedelta(days=days - 1)

        rows = (
            Order.objects
            .filter(created_at__date__gte=start_date)
            .annotate(day=TruncDate("created_at"))
            .values("day")
            .annotate(
                order_count=Count("id"),
                revenue=Sum("total_amount"),
            )
            .order_by("day")
        )

        data = [
            {
                "date": str(r["day"]),
                "order_count": r["order_count"],
                "revenue": float(r["revenue"] or 0),
            }
            for r in rows
        ]

        return Response({"days": days, "data": data})


# ─── Coupon views ─────────────────────────────────────────────────────────────

class CouponListCreateView(APIView):
    """Admin: list all coupons (GET) or create a new one (POST)."""

    permission_classes = [IsAdmin]

    def get(self, request):
        coupons = Coupon.objects.all().order_by("-created_at")
        return Response(CouponSerializer(coupons, many=True).data)

    def post(self, request):
        serializer = CouponWriteSerializer(data=request.data)
        if serializer.is_valid():
            coupon = serializer.save()
            return Response(CouponSerializer(coupon).data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CouponDetailView(APIView):
    """Admin: update (PATCH) or delete a coupon."""

    permission_classes = [IsAdmin]

    def _get(self, pk):
        try:
            return Coupon.objects.get(pk=pk)
        except Coupon.DoesNotExist:
            return None

    def patch(self, request, pk):
        coupon = self._get(pk)
        if not coupon:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = CouponWriteSerializer(coupon, data=request.data, partial=True)
        if serializer.is_valid():
            coupon = serializer.save()
            return Response(CouponSerializer(coupon).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        coupon = self._get(pk)
        if not coupon:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        coupon.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CouponToggleView(APIView):
    """Admin: toggle a coupon's is_active flag."""

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            coupon = Coupon.objects.get(pk=pk)
        except Coupon.DoesNotExist:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        coupon.is_active = not coupon.is_active
        coupon.save(update_fields=["is_active"])
        return Response(CouponSerializer(coupon).data)


class ActiveCouponListView(APIView):
    """Customer: list all active coupons."""

    permission_classes = [AllowAny]

    def get(self, request):
        now = timezone.now()
        coupons = Coupon.objects.filter(is_active=True).order_by("-created_at")
        valid_coupons = []
        for c in coupons:
            if c.valid_from and now < c.valid_from:
                continue
            if c.valid_until and now > c.valid_until:
                continue
            if c.usage_limit and c.usage_count >= c.usage_limit:
                continue
            valid_coupons.append(c)
        return Response(CouponSerializer(valid_coupons, many=True).data)


class ValidateCouponView(APIView):
    """Customer: validate a coupon code and preview the discount."""

    permission_classes = [IsAuthenticated]

    def post(self, request):
        code = request.data.get("code", "").strip()
        order_total = request.data.get("order_total")

        if not code:
            return Response({"detail": "Coupon code required."}, status=status.HTTP_400_BAD_REQUEST)
        if order_total is None:
            return Response({"detail": "order_total required."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            order_total = Decimal(str(order_total))
        except Exception:
            return Response({"detail": "Invalid order_total."}, status=status.HTTP_400_BAD_REQUEST)

        try:
            coupon = Coupon.objects.get(code__iexact=code, is_active=True)
        except Coupon.DoesNotExist:
            return Response({"valid": False, "detail": "Invalid or inactive coupon."}, status=status.HTTP_200_OK)

        now = timezone.now()
        if coupon.valid_from and now < coupon.valid_from:
            return Response({"valid": False, "detail": "Coupon is not yet valid."})
        if coupon.valid_until and now > coupon.valid_until:
            return Response({"valid": False, "detail": "Coupon has expired."})
        if coupon.usage_limit and coupon.usage_count >= coupon.usage_limit:
            return Response({"valid": False, "detail": "Coupon usage limit reached."})
        if order_total < coupon.min_order_amount:
            return Response({
                "valid": False,
                "detail": f"Minimum order amount is ₹{coupon.min_order_amount}.",
            })

        discount = coupon.compute_discount(order_total)

        return Response({
            "valid": True,
            "coupon": CouponSerializer(coupon).data,
            "discount_amount": str(discount),
            "final_total": str(order_total - discount),
        })





@method_decorator(csrf_exempt, name="dispatch")
class CashfreeWebhookView(APIView):
    """
    Cashfree webhook handler.

    Sandbox version:
    - Signature verification disabled
    - Handles PAYMENT_SUCCESS_WEBHOOK
    - Handles PAYMENT_FAILED_WEBHOOK
    """

    permission_classes = [AllowAny]

    def post(self, request):
        try:
            import json

            data = request.data

            logger.info(
                "Webhook payload:\n%s",
                json.dumps(data, indent=2)
            )

            event_type = data.get("type", "")
            event_data = data.get("data", {})

            logger.info(
                f"Webhook received: type={event_type}"
            )

            # -------------------------
            # PAYMENT SUCCESS
            # -------------------------
            if event_type == "PAYMENT_SUCCESS_WEBHOOK":

                order_id_str = (
                    event_data.get("order", {})
                    .get("order_id", "")
                )

                cf_payment_id = (
                    event_data.get("payment", {})
                    .get("cf_payment_id", "")
                )

                if not order_id_str:
                    logger.warning(
                        "PAYMENT_SUCCESS_WEBHOOK received without order_id"
                    )
                    return Response(
                        {"status": "success"},
                        status=status.HTTP_200_OK
                    )

                try:
                    order_number = "_".join(
                        order_id_str.split("_")[:-1]
                    )

                    order = Order.objects.get(
                        order_number=order_number
                    )

                    order.payment_status = "paid"
                    order.payment_id = str(cf_payment_id)

                    order.save(
                        update_fields=[
                            "payment_status",
                            "payment_id",
                            "updated_at"
                        ]
                    )

                    send_push_to_role(
                        'admin',
                        'Payment Received 💰',
                        f'Order #{order.order_number} has been paid online.',
                        {'order_id': str(order.id)},
                    )

                    logger.info(
                        f"Order marked PAID via webhook: "
                        f"{order.order_number}"
                    )

                except Order.DoesNotExist:
                    logger.warning(
                        f"Order not found: {order_id_str}"
                    )

            # -------------------------
            # PAYMENT FAILED
            # -------------------------
            elif event_type == "PAYMENT_FAILED_WEBHOOK":

                order_id_str = (
                    event_data.get("order", {})
                    .get("order_id", "")
                )

                logger.warning(
                    f"Payment failed for order: {order_id_str}"
                )

                try:
                    order_number = "_".join(
                        order_id_str.split("_")[:-1]
                    )

                    order = Order.objects.get(
                        order_number=order_number
                    )

                    order.payment_status = "failed"

                    order.save(
                        update_fields=[
                            "payment_status",
                            "updated_at"
                        ]
                    )

                except Order.DoesNotExist:
                    logger.warning(
                        f"Order not found: {order_id_str}"
                    )

            else:
                logger.info(
                    f"Ignoring webhook type: {event_type}"
                )

            return Response(
                {"status": "success"},
                status=status.HTTP_200_OK
            )

        except Exception as e:
            logger.exception(
                f"Webhook processing failed: {str(e)}"
            )

            return Response(
                {
                    "status": "error",
                    "message": str(e)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )


class ApplyDiscountView(APIView):
    """Chef or admin applies a flat rupee discount to an order.

    Re-bases off original_total so a second discount doesn't double-stack.
    Sets is_modified_by_staff so the customer sees the change popup.
    """

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        if order.status in ("delivered", "cancelled", "rejected"):
            return Response(
                {"detail": "Cannot apply discount to a completed order."},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = ApplyDiscountSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        discount = data["discount_amount"]
        reason = data.get("discount_reason", "")

        # Calculate true subtotal from items
        subtotal = sum(item.price * item.quantity for item in order.items.all())
        order.original_total = subtotal

        if discount > subtotal:
            return Response(
                {"detail": "Discount cannot exceed the original order total."},
                status=status.HTTP_400_BAD_REQUEST
            )

        order.discount_amount = discount
        order.discount_reason = reason
        order.total_amount = subtotal - discount
        order.is_modified_by_staff = True
        order.save(update_fields=[
            "discount_amount", "discount_reason",
            "total_amount", "original_total",
            "is_modified_by_staff", "updated_at"
        ])

        logger.info(
            f"Discount applied: order_id={order.id}, "
            f"discount={discount}, reason='{reason}', "
            f"new_total={order.total_amount}, user_id={request.user.id}"
        )

        return Response(OrderSerializer(order).data)


class AcknowledgeChangesView(APIView):
    """Customer accepts or rejects a staff-modified order.

    accepted=true  → clear the notification flag, order continues normally.
    accepted=false → reject the order; customer gets refund message via app.
    """

    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        serializer = AcknowledgeChangesSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        accepted = serializer.validated_data["accepted"]

        if accepted:
            order.is_modified_by_staff = False
            order.save(update_fields=["is_modified_by_staff", "updated_at"])
            logger.info(f"Customer accepted modified order: order_id={order.id}")
        else:
            order.status = "rejected"
            order.rejection_reason = "Customer rejected the modified order."
            order.is_modified_by_staff = False
            order.save(update_fields=[
                "status", "rejection_reason",
                "is_modified_by_staff", "updated_at"
            ])
            logger.info(f"Customer rejected modified order: order_id={order.id}")

        return Response(OrderSerializer(order).data)


class EditOrderItemsView(APIView):
    """Chef or admin edits order items before confirmation.

    Replaces all existing items with the submitted list and recalculates
    total_amount. Only allowed while status == 'pending_confirmation'.
    """

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        if order.status != "pending_confirmation":
            return Response(
                {"detail": "Items can only be edited before confirmation."},
                status=status.HTTP_400_BAD_REQUEST
            )

        items_data = request.data.get("items", [])
        if not items_data:
            return Response(
                {"detail": "At least one item is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        # Snapshot original total before any modification.
        pre_edit_total = order.total_amount

        # Delete existing items and recalculate.
        order.items.all().delete()
        total_amount = Decimal("0.00")

        for item in items_data:
            try:
                product = Product.objects.get(id=item["product_id"])
            except Product.DoesNotExist:
                return Response(
                    {"detail": f"Product {item['product_id']} not found."},
                    status=status.HTTP_400_BAD_REQUEST
                )

            quantity = int(item.get("quantity", 1))
            if quantity < 1:
                continue

            price = product.price
            total_amount += price * quantity

            OrderItem.objects.create(
                order=order,
                product=product,
                quantity=quantity,
                price=price,
            )

        # Check if the existing discount was from a coupon and recalculate/cap it
        discount_amount = order.discount_amount
        if order.discount_reason and order.discount_reason.startswith("Coupon: "):
            coupon_code = order.discount_reason.replace("Coupon: ", "").strip()
            try:
                coupon = Coupon.objects.get(code__iexact=coupon_code)
                if total_amount < coupon.min_order_amount:
                    discount_amount = Decimal("0.00")
                    order.discount_reason = ""
                else:
                    discount_amount = coupon.compute_discount(total_amount)
            except Coupon.DoesNotExist:
                discount_amount = min(discount_amount, total_amount)
        else:
            discount_amount = min(discount_amount, total_amount)

        order.discount_amount = discount_amount
        order.original_total = total_amount
        order.total_amount = total_amount - discount_amount
        order.is_modified_by_staff = True
        order.save(update_fields=[
            "total_amount", "original_total", "discount_amount", "discount_reason",
            "is_modified_by_staff", "updated_at"
        ])

        logger.info(
            f"Order items edited by staff: order_id={order.id}, "
            f"new_total={total_amount}, user_id={request.user.id}"
        )

        return Response(OrderSerializer(order).data)


class OrderReviewView(APIView):
    """Customer submits or retrieves a review for a delivered order."""

    permission_classes = [IsCustomer]

    def get(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)
        try:
            review = order.review
            product_reviews = ProductReview.objects.filter(order=order)
            items_data = []
            for pr in product_reviews:
                items_data.append({
                    "product_id": pr.product_id,
                    "rating": pr.rating,
                    "comment": pr.comment,
                })
            return Response({
                "rating": review.rating,
                "comment": review.comment,
                "submitted": True,
                "items": items_data,
            })
        except OrderReview.DoesNotExist:
            return Response({"submitted": False})

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user, status="delivered")
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found or not yet delivered."},
                status=status.HTTP_404_NOT_FOUND,
            )
        if hasattr(order, "review"):
            return Response({"detail": "Review already submitted."}, status=status.HTTP_400_BAD_REQUEST)

        rating = request.data.get("rating")
        comment = request.data.get("comment", "")
        if not rating or not (1 <= int(rating) <= 5):
            return Response({"detail": "Rating must be 1-5."}, status=status.HTTP_400_BAD_REQUEST)

        OrderReview.objects.create(
            order=order,
            customer=request.user,
            rating=int(rating),
            comment=comment,
        )

        items_reviews = request.data.get("items", [])
        for item_data in items_reviews:
            p_id = item_data.get("product_id")
            p_rating = item_data.get("rating")
            p_comment = item_data.get("comment", "")
            if p_id and p_rating:
                from products.models import Product
                try:
                    product = Product.objects.get(pk=p_id)
                    ProductReview.objects.create(
                        product=product,
                        customer=request.user,
                        order=order,
                        rating=int(p_rating),
                        comment=p_comment,
                    )
                except Product.DoesNotExist:
                    pass

        # Update product ratings based on all ProductReview instances for that product
        from products.models import Product
        from django.db.models import Avg
        for item in order.items.all():
            avg = ProductReview.objects.filter(
                product=item.product
            ).aggregate(avg=Avg("rating"))["avg"]
            if avg is not None:
                Product.objects.filter(pk=item.product_id).update(rating=round(avg, 1))
            else:
                avg_overall = OrderReview.objects.filter(
                    order__items__product=item.product
                ).aggregate(avg=Avg("rating"))["avg"] or 0
                Product.objects.filter(pk=item.product_id).update(rating=round(avg_overall, 1))

        return Response({"detail": "Review submitted. Thank you!"}, status=status.HTTP_201_CREATED)


class QueuePositionView(APIView):
    """Returns this order's position in the pending/confirmed queue."""

    permission_classes = [IsCustomer]

    def get(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if order.status not in ("pending_confirmation", "confirmed"):
            return Response({"position": None, "ahead": 0})

        ahead = Order.objects.filter(
            status__in=("pending_confirmation", "confirmed"),
            created_at__lt=order.created_at,
        ).count()

        return Response({"position": ahead + 1, "ahead": ahead})


class UpdateDeliveryLocationView(APIView):
    """Delivery person posts their current GPS coordinates for an active order."""

    permission_classes = [IsDelivery]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, assigned_delivery=request.user)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if order.status != "out_for_delivery":
            return Response(
                {"detail": "Location updates only allowed when out for delivery."},
                status=status.HTTP_400_BAD_REQUEST
            )

        serializer = UpdateDeliveryLocationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        order.delivery_latitude = serializer.validated_data["latitude"]
        order.delivery_longitude = serializer.validated_data["longitude"]
        order.delivery_location_updated_at = timezone.now()
        order.save(update_fields=[
            "delivery_latitude", "delivery_longitude",
            "delivery_location_updated_at"
        ])

        _broadcast_order(order, "order_update")

        return Response({"detail": "Location updated."})


class GetDeliveryLocationView(APIView):
    """Customer polls for the delivery person's current GPS location."""

    permission_classes = [IsAuthenticated]

    def get(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        # RBAC Check: Only the placing customer, assigned driver, or admin can track the location
        if not (request.user == order.user or request.user == order.assigned_delivery or request.user.role == "admin"):
            return Response(
                {"detail": "You do not have permission to view this order's location."},
                status=status.HTTP_403_FORBIDDEN
            )

        if order.delivery_latitude is None:
            return Response({"available": False})

        return Response({
            "available": True,
            "latitude": str(order.delivery_latitude),
            "longitude": str(order.delivery_longitude),
            "updated_at": order.delivery_location_updated_at,
        })


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


class AdminCreateOrderView(APIView):
    """Admin manually places an order for a customer by their phone number."""
    permission_classes = [IsAdmin]

    def post(self, request):
        phone_number = request.data.get("phone_number", "").strip()
        customer_name = request.data.get("customer_name", "").strip()
        delivery_type = request.data.get("delivery_type", "delivery") # delivery or pickup
        address_text = request.data.get("address_text", "").strip()
        address_id = request.data.get("address_id")
        
        # Split Address Fields
        house = request.data.get("house", "").strip()
        street = request.data.get("street", "").strip()
        landmark = request.data.get("landmark", "").strip()
        city = request.data.get("city", "").strip()
        pincode = request.data.get("pincode", "").strip()

        items = request.data.get("items", [])
        payment_method = request.data.get("payment_method", "cod") # cod or prepaid
        coupon_code = request.data.get("coupon_code", "").strip()
        delivery_notes = request.data.get("delivery_notes", "").strip()

        if not phone_number:
            return Response({"detail": "Phone number is required."}, status=status.HTTP_400_BAD_REQUEST)
        
        if not items:
            return Response({"detail": "At least one item is required."}, status=status.HTTP_400_BAD_REQUEST)

        # 1. Get or create the User
        normalized_phone = normalize_phone_number(phone_number)
        raw_10_digit = phone_number[-10:] if len(phone_number) >= 10 else phone_number

        user = User.objects.filter(
            Q(phone_number=phone_number) |
            Q(phone_number=normalized_phone) |
            Q(phone_number__endswith=raw_10_digit)
        ).first()

        if user:
            # Normalize user's phone if it wasn't
            if user.phone_number != normalized_phone:
                user.phone_number = normalized_phone
                user.save(update_fields=["phone_number"])
            # Update name if provided (filled)
            if customer_name:
                user.name = customer_name
                user.save(update_fields=["name"])
        else:
            user = User.objects.create_user(
                phone_number=normalized_phone,
                name=customer_name or "Guest Customer",
                role="customer"
            )

        # 2. Get or create Address
        address = None
        if address_id:
            try:
                address = Address.objects.get(user=user, id=address_id)
            except Address.DoesNotExist:
                address = None

        if not address:
            if delivery_type == "pickup":
                house_text = "Store Pickup"
                street_text = ""
                landmark_text = ""
                city_text = "Sojat Road"
                pincode_text = "306103"
            else:
                house_text = house or address_text or "Delivery"
                street_text = street
                landmark_text = landmark
                city_text = city or "Sojat Road"
                pincode_text = pincode or "306103"

            # Find if user already has an address with these exact details
            address = Address.objects.filter(
                user=user,
                house=house_text,
                street=street_text,
                landmark=landmark_text,
                city=city_text,
                pincode=pincode_text
            ).first()
            
            if not address:
                address = Address.objects.create(
                    user=user,
                    label="Home" if delivery_type == "delivery" else "Other",
                    house=house_text,
                    street=street_text,
                    landmark=landmark_text,
                    city=city_text,
                    pincode=pincode_text,
                    latitude=Decimal("25.861129"),
                    longitude=Decimal("73.749306"),
                    is_default=True
                )

        # 3. Calculate total and check coupon
        total_amount = Decimal("0.00")
        coupon = None
        if coupon_code:
            try:
                coupon = Coupon.objects.get(code__iexact=coupon_code, is_active=True)
            except Coupon.DoesNotExist:
                return Response({"detail": "Invalid or expired coupon code."}, status=status.HTTP_400_BAD_REQUEST)

        order = Order.objects.create(
            user=user,
            address=address,
            payment_method=payment_method,
            payment_status="paid" if payment_method == "prepaid" else "pending",
            delivery_notes=delivery_notes,
            total_amount=Decimal("0.00"),
            status="confirmed" # Admin-placed order is auto-confirmed
        )

        for item in items:
            product_id = item.get("product_id")
            quantity = int(item.get("quantity", 1))
            
            try:
                product = Product.objects.get(id=product_id)
            except Product.DoesNotExist:
                order.delete()
                return Response({"detail": f"Product with ID {product_id} not found."}, status=status.HTTP_400_BAD_REQUEST)

            item_price = product.price
            customization_price = Decimal("0.00")
            selections = item.get("selections", [])
            for sel in selections:
                extra = Decimal(str(sel.get("price", 0.0)))
                customization_price += extra

            final_price = item_price + customization_price
            total_amount += final_price * quantity

            OrderItem.objects.create(
                order=order,
                product=product,
                quantity=quantity,
                price=final_price
            )

        order.total_amount = total_amount

        # Apply coupon
        if coupon:
            now = timezone.now()
            if coupon.valid_from and now < coupon.valid_from:
                order.delete()
                return Response({"detail": "Coupon is not yet valid."}, status=status.HTTP_400_BAD_REQUEST)
            if coupon.valid_until and now > coupon.valid_until:
                order.delete()
                return Response({"detail": "Coupon has expired."}, status=status.HTTP_400_BAD_REQUEST)
            if coupon.usage_limit and coupon.usage_count >= coupon.usage_limit:
                order.delete()
                return Response({"detail": "Coupon usage limit reached."}, status=status.HTTP_400_BAD_REQUEST)
            if total_amount < coupon.min_order_amount:
                order.delete()
                return Response({"detail": f"Minimum order amount for this coupon is ₹{coupon.min_order_amount}."}, status=status.HTTP_400_BAD_REQUEST)
            
            discount = coupon.compute_discount(total_amount)
            order.discount_amount = discount
            order.discount_reason = f"Coupon: {coupon.code}"
            order.original_total = total_amount
            order.total_amount = total_amount - discount
            Coupon.objects.filter(pk=coupon.pk).update(usage_count=coupon.usage_count + 1)

        order.save()

        # Send push notification to user (if FCM token is available)
        try:
            send_push(
                user,
                'Order Placed 🛍️',
                f'An order has been placed for you: Order #{order.order_number}',
                {'order_id': str(order.id), 'type': 'order'}
            )
        except Exception as e:
            logger.warning(f"Could not send push notification: {e}")

        # Broadcast to other channels
        _broadcast_order(order, "new_order")

        return Response(OrderSerializer(order).data, status=status.HTTP_201_CREATED)


class AdminReviewsListView(generics.ListAPIView):
    """Admin: list all reviews submitted by customers (paginated)."""
    permission_classes = [IsAdmin]
    pagination_class = OrderPagination

    def get(self, request):
        reviews = OrderReview.objects.all().order_by("-created_at")
        page = self.paginate_queryset(reviews)
        if page is not None:
            serializer = OrderReviewSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = OrderReviewSerializer(reviews, many=True)
        return Response(serializer.data)


class AdminProductReviewsListView(generics.ListAPIView):
    """Admin: list all product/dish reviews submitted by customers (paginated)."""
    permission_classes = [IsAdmin]
    pagination_class = OrderPagination

    def get(self, request):
        reviews = ProductReview.objects.all().order_by("-created_at")
        page = self.paginate_queryset(reviews)
        if page is not None:
            serializer = ProductReviewSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = ProductReviewSerializer(reviews, many=True)
        return Response(serializer.data)


def initiate_cashfree_refund(order, reason):
    import uuid
    if not order.cashfree_order_id:
        return False
    refund_id = f"ref_{order.order_number}_{uuid.uuid4().hex[:6]}"
    try:
        url = f"{settings.CASHFREE_BASE_URL}/orders/{order.cashfree_order_id}/refunds"
        headers = {
            "x-client-id": settings.CASHFREE_APP_ID,
            "x-client-secret": settings.CASHFREE_SECRET_KEY,
            "x-api-version": settings.CASHFREE_API_VERSION,
            "Content-Type": "application/json"
        }
        payload = {
            "refund_amount": float(order.total_amount),
            "refund_id": refund_id,
            "refund_note": reason or "Cancellation refund"
        }
        res = requests.post(url, json=payload, headers=headers, timeout=10)
        if res.status_code in [200, 201]:
            return True
    except Exception as e:
        logger.warning(f"Refund initiation failed: {e}")
    return False


class RequestCancellationView(APIView):
    """Customer: Request cancellation for an order."""
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if order.status in ["delivered", "cancelled", "rejected"]:
            return Response(
                {"detail": "Cannot request cancellation for this order."},
                status=status.HTTP_400_BAD_REQUEST
            )

        reason = request.data.get("reason", "").strip()
        if not reason:
            return Response(
                {"detail": "Cancellation reason is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        order.cancellation_requested = True
        order.cancellation_reason = reason
        order.cancellation_requested_at = timezone.now()
        order.save()

        # Notify admins via websocket
        _broadcast_order(order, "cancellation_requested")

        return Response(OrderSerializer(order).data)


class AdminHandleCancellationView(APIView):
    """Admin: Approve or decline a cancellation request."""
    permission_classes = [IsAdmin]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        action = request.data.get("action", "").strip() # "approve" or "reject"
        reason = request.data.get("reason", "").strip()

        if action not in ["approve", "reject"]:
            return Response(
                {"detail": "Action must be either 'approve' or 'reject'."},
                status=status.HTTP_400_BAD_REQUEST
            )

        if action == "approve":
            order.cancellation_approved = True
            order.status = "cancelled"
            if reason:
                order.cancellation_reason = reason

            if order.coins_redeemed > 0:
                customer = order.user
                customer.loyalty_coins = getattr(customer, 'loyalty_coins', 0) + order.coins_redeemed
                customer.save(update_fields=['loyalty_coins'])

            # Initiate Cashfree Refund if paid online
            if order.payment_method == "online" and order.payment_status == "paid":
                success = initiate_cashfree_refund(order, reason or "Customer Cancellation Request Approved")
                if success:
                    order.refund_status = "initiated"
                    order.payment_status = "refunded"
                else:
                    order.refund_status = "failed"
            else:
                order.refund_status = "not_applicable"

            try:
                send_push(
                    order.user,
                    "Order Cancelled 🚫",
                    f"Your cancellation request for order #{order.order_number} has been approved.",
                    {"order_id": str(order.id), "type": "order"}
                )
            except Exception as e:
                logger.warning(f"Could not send push notification: {e}")
        else:
            order.cancellation_approved = False
            order.cancellation_requested = False # reset so they can request again if needed
            try:
                send_push(
                    order.user,
                    "Cancellation Request Declined ⚠️",
                    f"Your cancellation request for order #{order.order_number} was declined.",
                    {"order_id": str(order.id), "type": "order"}
                )
            except Exception as e:
                logger.warning(f"Could not send push notification: {e}")

        order.save()
        _broadcast_order(order)

        return Response(OrderSerializer(order).data)


class AdminCancelOrderView(APIView):
    """Admin: Cancel order directly at any stage."""
    permission_classes = [IsAdmin]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        reason = request.data.get("reason", "").strip()
        if not reason:
            return Response(
                {"detail": "Cancellation reason is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        order.status = "cancelled"
        order.cancellation_reason = reason
        order.cancellation_approved = True

        if order.coins_redeemed > 0:
            customer = order.user
            customer.loyalty_coins = getattr(customer, 'loyalty_coins', 0) + order.coins_redeemed
            customer.save(update_fields=['loyalty_coins'])

        # Initiate Cashfree Refund if paid online
        if order.payment_method == "online" and order.payment_status == "paid":
            success = initiate_cashfree_refund(order, reason)
            if success:
                order.refund_status = "initiated"
                order.payment_status = "refunded"
            else:
                order.refund_status = "failed"
        else:
            order.refund_status = "not_applicable"

        order.save()
        _broadcast_order(order)

        try:
            send_push(
                order.user,
                "Order Cancelled 🚫",
                f"Your order #{order.order_number} has been cancelled by the kitchen: {reason}",
                {"order_id": str(order.id), "type": "order"}
            )
        except Exception as e:
            logger.warning(f"Could not send push notification: {e}")

        return Response(OrderSerializer(order).data)


from .models import OrderMessage
from .serializers import OrderMessageSerializer

class OrderMessageListCreateView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, order_id):
        try:
            order = Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            return Response({"error": "Order not found"}, status=status.HTTP_404_NOT_FOUND)

        if request.user.role != "admin" and order.user != request.user and order.assigned_delivery != request.user:
            return Response({"error": "Unauthorized access"}, status=status.HTTP_403_FORBIDDEN)

        messages = OrderMessage.objects.filter(order=order).order_by("created_at")
        serializer = OrderMessageSerializer(messages, many=True)
        return Response(serializer.data)

    def post(self, request, order_id):
        try:
            order = Order.objects.get(id=order_id)
        except Order.DoesNotExist:
            return Response({"error": "Order not found"}, status=status.HTTP_404_NOT_FOUND)

        if request.user.role != "admin" and order.user != request.user and order.assigned_delivery != request.user:
            return Response({"error": "Unauthorized access"}, status=status.HTTP_403_FORBIDDEN)

        from authentication.utils import sanitize_text
        message_text = sanitize_text(request.data.get("message", "").strip())
        if not message_text:
            return Response({"error": "Message cannot be empty"}, status=status.HTTP_400_BAD_REQUEST)

        is_admin = (request.user.role == "admin")
        msg = OrderMessage.objects.create(
            order=order,
            sender=request.user,
            message=message_text,
            is_admin=is_admin
        )

        try:
            channel_layer = get_channel_layer()
            if channel_layer is not None:
                data = OrderMessageSerializer(msg).data
                payload = {
                    "type": "order_update",
                    "data": {
                        "type": "chat_message",
                        "message": data
                    }
                }
                async_to_sync(channel_layer.group_send)(f"order_{order.id}", payload)
        except Exception as e:
            logger.warning(f"Failed to broadcast websocket chat message: {e}")

        try:
            if is_admin:
                send_push(
                    order.user,
                    "Message from Kitchen 💬",
                    message_text,
                    data={
                        "type": "chat",
                        "order_id": order.id,
                        "order_number": order.order_number,
                    }
                )
        except Exception as e:
            logger.warning(f"Could not send chat push notification: {e}")

        return Response(OrderMessageSerializer(msg).data, status=status.HTTP_201_CREATED)


class ReportNotReceivedView(APIView):
    """
    Customer reports that their order was marked delivered but they
    didn't actually receive it. Flags the order and notifies admin.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if order.user != request.user:
            return Response({"detail": "Not your order."}, status=status.HTTP_403_FORBIDDEN)

        if order.status != "delivered":
            return Response(
                {"detail": "You can only report non-receipt for delivered orders."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if order.not_received_reported:
            return Response({"detail": "Already reported."}, status=status.HTTP_400_BAD_REQUEST)

        order.not_received_reported = True
        order.not_received_reported_at = timezone.now()
        order.save(update_fields=["not_received_reported", "not_received_reported_at"])

        # Alert admin via push notification
        try:
            send_push_to_role(
                "admin",
                f"⚠️ Order Not Received – #{order.order_number}",
                f"{order.user.name or order.user.phone_number} says they didn't receive their order.",
                data={"order_id": str(order.id), "type": "order"},
            )
        except Exception as e:
            logger.warning(f"Could not send not-received push: {e}")

        # Broadcast updated order so admin dashboard refreshes
        _broadcast_order(order)

        return Response(OrderSerializer(order).data)


class AdminPaymentMethodView(APIView):
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if not (hasattr(request.user, "role") and request.user.role == "admin"):
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

        serializer = AdminPaymentMethodSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        action = serializer.validated_data.get("action", "change_method")

        if order.status in ("delivered", "cancelled", "rejected"):
            return Response(
                {"detail": "Payment cannot be changed after order is terminal."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if action == "mark_paid":
            if order.payment_method != "cod":
                return Response(
                    {"detail": "Only COD orders can be marked paid manually."},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if order.payment_status == "paid":
                return Response(OrderSerializer(order).data)
            order.payment_status = "paid"
            order.payment_id = order.payment_id or f"COD-{order.order_number}"
            order.save(update_fields=["payment_status", "payment_id", "updated_at"])
            _broadcast_order(order)
            return Response(OrderSerializer(order).data)

        method = serializer.validated_data.get("payment_method")
        if not method:
            return Response(
                {"detail": "payment_method is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if order.payment_status == "paid":
            return Response(
                {"detail": "Payment method cannot be changed after payment is paid."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        order.payment_method = method
        order.payment_status = "pending"
        if method == "cod":
            order.cashfree_order_id = ""
            order.payment_session_id = ""
        order.save(update_fields=[
            "payment_method",
            "payment_status",
            "cashfree_order_id",
            "payment_session_id",
            "updated_at",
        ])
        _broadcast_order(order)
        return Response(OrderSerializer(order).data)


class AdminOverrideStatusView(APIView):
    """
    Admin can force-set an order to ANY status, bypassing the normal
    delivery-staff-only / step-by-step restrictions. Useful for correcting
    wrongly-marked deliveries or other operator errors.

    Handles loyalty coin corrections automatically:
    - If overriding AWAY from 'delivered': reverses any coins earned.
    - If overriding TO 'delivered' from a non-delivered state: awards coins.
    """
    permission_classes = [IsAuthenticated]

    def patch(self, request, pk):
        try:
            order = Order.objects.get(pk=pk)
        except Order.DoesNotExist:
            return Response({"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND)

        if not (hasattr(request.user, "role") and request.user.role == "admin"):
            return Response({"detail": "Admin access required."}, status=status.HTTP_403_FORBIDDEN)

        new_status = request.data.get("status", "").strip()
        valid_statuses = [s[0] for s in Order.STATUS_CHOICES]
        if new_status not in valid_statuses:
            return Response(
                {"detail": f"Invalid status. Choose from: {', '.join(valid_statuses)}"},
                status=status.HTTP_400_BAD_REQUEST,
            )

        old_status = order.status

        # ── Loyalty coin corrections ───────────────────────────────────────────
        # If we're un-delivering (moving away from delivered), reverse earned coins.
        if old_status == "delivered" and new_status != "delivered":
            if order.coins_earned > 0:
                customer = order.user
                customer.loyalty_coins = max(0, getattr(customer, "loyalty_coins", 0) - order.coins_earned)
                customer.save(update_fields=["loyalty_coins"])
                order.coins_earned = 0

        # If we're re-delivering (moving to delivered from non-delivered), award coins.
        if new_status == "delivered" and old_status != "delivered":
            block_reason = _delivery_block_reason(order)
            if block_reason:
                return Response(
                    {"detail": block_reason},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            from app_config.models import SiteConfig
            percentage = SiteConfig.get().loyalty_coins_percentage
            earned = int((order.total_amount * percentage) // 100)
            if earned > 0:
                customer = order.user
                customer.loyalty_coins = getattr(customer, "loyalty_coins", 0) + earned
                customer.save(update_fields=["loyalty_coins"])
                order.coins_earned = earned

        # If overriding away from delivered, also clear not_received flag
        # (fresh state so customer can re-report if needed after re-delivery).
        if old_status == "delivered" and new_status != "delivered":
            order.not_received_reported = False
            order.not_received_reported_at = None

        order.status = new_status
        order.save()

        # Push notification to customer
        _push_map = {
            "preparing": ("Kitchen is preparing your order 👨‍🍳", "Your food is being freshly prepared!"),
            "out_for_delivery": ("On the way! 🛵", f"Order #{order.order_number} is out for delivery."),
            "delivered": ("Order Delivered! 🎉", "Rate your food and share your feedback ⭐"),
            "confirmed": ("Order Confirmed ✅", f"Your order #{order.order_number} has been confirmed."),
        }
        if new_status in _push_map:
            title, body = _push_map[new_status]
            send_push(order.user, title, body, {"order_id": str(order.id), "type": "order"})

        _broadcast_order(order)

        return Response(OrderSerializer(order).data)

