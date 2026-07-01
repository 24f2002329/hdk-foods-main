# Database Architecture & Migrations

This document explains the database structure, model locations, table-mapping strategies, and migration techniques used in the HDK Foods backend.

---

## 1. Database Model Locations

To keep database tables consistent and preserve historical records, migrated models explicit map to their original legacy tables using Django Meta options.

| Original Model | Legacy Table Name | Current App | Current Model Class |
| :--- | :--- | :--- | :--- |
| `orders.Coupon` | `orders_coupon` | `offers` | `offers.models.Coupon` |
| `orders.PrepConfig` | `orders_prepconfig` | `analytics` | `analytics.models.PrepConfig` |
| `orders.OrderReview` | `orders_orderreview` | `reviews` | `reviews.models.OrderReview` |
| `orders.ProductReview` | `orders_productreview` | `reviews` | `reviews.models.ProductReview` |
| `app_config.Notification` | `app_config_notification` | `notifications` | `notifications.models.Notification` |
| `orders.OrderMessage` | `orders_ordermessage` | `support` | `support.models.OrderMessage` |

---

## 2. Zero-Downtime Migration Strategy

To move models between apps without dropping and recreating tables (which would cause total data loss in production), we utilize Django's **`SeparateDatabaseAndState`** migration feature.

### Deletion Migrations (Legacy App)
We tell the database *not* to run `DROP TABLE` SQL, but instruct Django to update its internal state to reflect the model deletion:
```python
# orders/migrations/0019_delete_coupon_and_more.py
operations = [
    migrations.SeparateDatabaseAndState(
        database_operations=[],  # Empty -> Executes no SQL on the DB
        state_operations=[
            migrations.DeleteModel(name='Coupon'),
            # ...
        ]
    )
]
```

### Creation Migrations (New Domain App)
We tell the database *not* to run `CREATE TABLE` SQL (since the table already exists under the mapped `db_table`), but update Django's state:
```python
# offers/migrations/0001_initial.py
operations = [
    migrations.SeparateDatabaseAndState(
        database_operations=[],  # Empty -> No SQL executed
        state_operations=[
            migrations.CreateModel(
                name='Coupon',
                # ...
                options={'db_table': 'orders_coupon'},
            )
        ]
    )
]
```

---

## 3. Loyalty Coin Transactions Schema

A new model `CoinTransaction` is introduced in the `loyalty` app to log users' HDK Coins transactions history.

### Model Definition (`loyalty/models.py`)
```python
class CoinTransaction(models.Model):
    TRANSACTION_TYPES = [
        ('earned', 'Earned'),
        ('redeemed', 'Redeemed'),
        ('reversed', 'Reversed'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="coin_transactions")
    amount = models.IntegerField()
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_TYPES)
    description = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
```
This enables transaction histories to be logged whenever a user completes an order (earned), uses coins at checkout (redeemed), or has their order cancelled/refunded (reversed).
