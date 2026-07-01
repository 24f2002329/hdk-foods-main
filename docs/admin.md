# Admin Dashboard & Kitchen Display System (KDS)

This document covers the admin management console (`frontend_admin`), KDS workflows, and prep time configuration settings.

---

## 1. Kitchen Display System (KDS)

The KDS screen allows kitchen managers to track, confirm, and update the status of incoming orders in real-time.

```
+-------------------------------------------------------------+
| KDS Board                                                  |
+-----------------------------+-------------------------------+
| Preparing                   | Out For Delivery              |
+-----------------------------+-------------------------------+
| Order #1002 (3m ago)        | Order #1000 (15m ago)         |
|  - 2x Paneer Tikka Wrap     |  - Driver: Devendra           |
|  - 1x Cheese Garlic Bread   |  - Status: Dispatched         |
| [ MARK READY ]              | [ VIEW MAP ]                  |
+-----------------------------+-------------------------------+
```

* **Real-time Synchronization**: Powered by a WebSocket channel listening to `/ws/admin/orders/`. New orders immediately appear as cards on the board.
* **Transition Workflows**: Clicking `MARK READY` updates the backend status from `preparing` to `out_for_delivery` or `ready_for_pickup`, triggering push notifications to the customer and dispatch alerts to delivery riders.

---

## 2. Admin Order Creation

Administrators can manually create orders for phone-in customers or custom corporate events:
* **Custom User Lookups**: Search existing customer profiles by phone number.
* **Product Builders**: Add products, configure modifiers (toppings, sizes), and override base pricing.
* **Payment Overrides**: Select payment type (Online link, cash, or credit terms) and apply custom coupons directly.

---

## 3. Preparation Forecast Tuning (`PrepConfig`)

To ensure accurate prep time predictions on the customer app, administrators can configure kitchen variables dynamically in the Admin Dashboard:

* **Queue Multiplier**: Minutes added per active order in the kitchen queue.
* **Rush Hour Bonus**: Flat minutes added to estimates during peak times.
* **Peak Window Settings**: Start/End time boundaries and active weekdays (e.g., Friday, Saturday, Sunday).
* **Override Boost**: Manual buffer values (positive or negative) applied globally during special events or kitchen maintenance.
