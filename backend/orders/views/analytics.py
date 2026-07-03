from decimal import Decimal
from datetime import timedelta
from django.utils import timezone
from django.db.models import Sum, Count, F, Avg, ExpressionWrapper, DurationField
from django.db.models.functions import TruncDate, ExtractHour
from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import AllowAny

from authentication.permissions import IsAdmin
from orders.models import Order, OrderItem, OrderReview
from orders.utils import calculate_predicted_prep_time


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

        period_qs = Order.objects.filter(created_at__date__gte=start_date)

        total_orders = period_qs.count()

        revenue = (
            period_qs.filter(payment_status="paid").aggregate(
                total=Sum("total_amount")
            )["total"]
            or 0
        )

        delivered_count = period_qs.filter(status="delivered").count()

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
            period_qs.annotate(hour=ExtractHour("created_at"))
            .values("hour")
            .annotate(count=Count("id"))
            .order_by("hour")
        )
        hourly_data = {h["hour"]: h["count"] for h in hourly_dist}
        hourly_list = [{"hour": h, "count": hourly_data.get(h, 0)} for h in range(24)]

        # Always-live counts — current queue state, not date-filtered
        pending_orders = Order.objects.filter(status="pending_confirmation").count()

        active_deliveries = Order.objects.filter(status="out_for_delivery").count()

        in_progress = Order.objects.filter(
            status__in=["confirmed", "preparing"]
        ).count()

        # Operational Insights Calculations
        prep_orders = period_qs.filter(
            confirmed_at__isnull=False, out_for_delivery_at__isnull=False
        )
        if prep_orders.exists():
            avg_prep_duration = prep_orders.annotate(
                prep_duration=ExpressionWrapper(
                    F("out_for_delivery_at") - F("confirmed_at"),
                    output_field=DurationField(),
                )
            ).aggregate(avg_prep=Avg("prep_duration"))["avg_prep"]
            avg_prep_time_minutes = (
                round(avg_prep_duration.total_seconds() / 60, 1)
                if avg_prep_duration
                else 0.0
            )
        else:
            avg_prep_time_minutes = 0.0

        delivery_orders = period_qs.filter(
            out_for_delivery_at__isnull=False, delivered_at__isnull=False
        )
        if delivery_orders.exists():
            avg_del_duration = delivery_orders.annotate(
                del_duration=ExpressionWrapper(
                    F("delivered_at") - F("out_for_delivery_at"),
                    output_field=DurationField(),
                )
            ).aggregate(avg_del=Avg("del_duration"))["avg_del"]
            avg_delivery_time_minutes = (
                round(avg_del_duration.total_seconds() / 60, 1)
                if avg_del_duration
                else 0.0
            )
        else:
            avg_delivery_time_minutes = 0.0

        # Peak Hour
        max_count = -1
        peak_hour_val = None
        for h_data in hourly_list:
            if h_data["count"] > max_count:
                max_count = h_data["count"]
                peak_hour_val = h_data["hour"]

        if peak_hour_val is not None and max_count > 0:
            hr = peak_hour_val
            suffix = "PM" if hr >= 12 else "AM"
            hr_display = 12 if hr == 0 else (hr if hr <= 12 else hr - 12)
            peak_hour = f"{hr_display:02d}:00 {suffix}"
        else:
            peak_hour = "N/A"

        # Repeat Customers Count
        repeat_customers_count = (
            period_qs.values("user")
            .annotate(order_count=Count("id"))
            .filter(order_count__gt=1)
            .count()
        )

        # COD / Online Split
        if total_orders > 0:
            cod_count = period_qs.filter(payment_method="cod").count()
            cod_percentage = round((cod_count / total_orders) * 100, 1)
            online_percentage = round(100.0 - cod_percentage, 1)
        else:
            cod_percentage = 0.0
            online_percentage = 0.0

        # Today's and Month's revenue
        today_revenue = (
            Order.objects.filter(
                payment_status="paid", created_at__date=today
            ).aggregate(total=Sum("total_amount"))["total"]
            or 0
        )
        month_revenue = (
            Order.objects.filter(
                payment_status="paid",
                created_at__year=today.year,
                created_at__month=today.month,
            ).aggregate(total=Sum("total_amount"))["total"]
            or 0
        )

        return Response(
            {
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
                "avg_prep_time_minutes": avg_prep_time_minutes,
                "avg_delivery_time_minutes": avg_delivery_time_minutes,
                "peak_hour": peak_hour,
                "repeat_customers_count": repeat_customers_count,
                "cod_percentage": cod_percentage,
                "online_percentage": online_percentage,
                "today_revenue": float(today_revenue),
                "month_revenue": float(month_revenue),
            }
        )


class DailyAnalyticsView(APIView):
    """Return per-day order count and revenue for the last N days (default 30)."""

    permission_classes = [IsAdmin]

    def get(self, request):
        days = int(request.query_params.get("days", 30))
        days = max(1, min(days, 365))
        start_date = timezone.now().date() - timedelta(days=days - 1)

        rows = (
            Order.objects.filter(created_at__date__gte=start_date)
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


class PredictPrepTimeView(APIView):
    """Returns predicted preparation time and delivery time for a set of product IDs before ordering."""

    permission_classes = [AllowAny]

    def get(self, request):
        product_ids_str = request.query_params.get("product_ids", "")
        if not product_ids_str:
            return Response(
                {"detail": "product_ids query parameter is required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            product_ids = [
                int(pid.strip())
                for pid in product_ids_str.split(",")
                if pid.strip().isdigit()
            ]
        except ValueError:
            return Response(
                {"detail": "Invalid product_ids format."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        prep_minutes = calculate_predicted_prep_time(product_ids)
        delivery_minutes = prep_minutes + 15

        return Response(
            {
                "predicted_preparation_time": prep_minutes,
                "predicted_delivery_time_minutes": delivery_minutes,
            }
        )
