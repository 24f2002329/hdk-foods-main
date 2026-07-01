from datetime import time
from django.utils import timezone
from products.models import Product
from .models import Order, PrepConfig


def calculate_predicted_prep_time(product_ids):
    """
    Calculate the predicted preparation time (in minutes) for a list of products.
    Formula: max_base_prep + (queue_multiplier * active_orders_count) + rush_hour_bonus + override_boost
    """
    if not product_ids:
        return 0

    # Get the products
    products = Product.objects.filter(id__in=product_ids)
    if not products.exists():
        return 0

    # 1. Base Prep Time: maximum base prep minutes among all items in the order
    max_base_prep = 0
    for product in products:
        base_prep = getattr(
            product, "base_prep_minutes", getattr(product, "preparation_time", 15)
        )
        if base_prep > max_base_prep:
            max_base_prep = base_prep

    # Get configuration (singleton)
    config = PrepConfig.get()

    # 2. Queue Multiplier: number of active orders currently in "pending_confirmation", "confirmed", or "preparing"
    active_orders_count = Order.objects.filter(
        status__in=["pending_confirmation", "confirmed", "preparing"]
    ).count()
    queue_time = config.queue_multiplier * active_orders_count

    # 3. Rush Hour Factor
    rush_hour_bonus = 0
    now = timezone.now()
    # Convert now to India Standard Time (Asia/Kolkata) since that is the local store timezone defined in SiteConfig
    try:
        import zoneinfo

        tz = zoneinfo.ZoneInfo("Asia/Kolkata")
    except ImportError:
        import pytz

        tz = pytz.timezone("Asia/Kolkata")

    now_local = now.astimezone(tz)
    weekday = now_local.weekday()  # 0 = Monday, 6 = Sunday
    current_time = now_local.time()

    # Check if weekday is in peak_weekdays (comma-separated list of integers)
    if config.peak_weekdays:
        try:
            peak_weekdays_list = [
                int(x.strip())
                for x in config.peak_weekdays.split(",")
                if x.strip().isdigit()
            ]
        except ValueError:
            peak_weekdays_list = [4, 5, 6]  # Fallback to Fri-Sun
    else:
        peak_weekdays_list = []

    if weekday in peak_weekdays_list:
        # Check if current time is within peak_start_time and peak_end_time
        if config.peak_start_time <= config.peak_end_time:
            is_peak_hour = (
                config.peak_start_time <= current_time <= config.peak_end_time
            )
        else:
            is_peak_hour = (
                current_time >= config.peak_start_time
                or current_time <= config.peak_end_time
            )

        if is_peak_hour:
            rush_hour_bonus = config.rush_hour_bonus

    # 4. Admin Override
    override_boost = config.override_boost

    total_predicted = int(max_base_prep + queue_time + rush_hour_bonus + override_boost)
    return max(0, total_predicted)
