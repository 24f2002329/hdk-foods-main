import uuid
import requests
import logging
from django.conf import settings
from orders.models import Order
from payments.models import (
    Gateway,
    Payment,
    PaymentAttempt,
    PaymentMethod,
    PaymentStatus,
)

logger = logging.getLogger(__name__)


def select_payment_method(order: Order, payment_method: str, user) -> dict:
    """
    Selects payment method for the order.
    Returns checkout details for online payments or confirmation for COD.
    """
    if payment_method == "cod":
        order.payment_method = "cod"
        order.payment_status = "pending"
        order.save(update_fields=["payment_method", "payment_status", "updated_at"])

        payment = _get_or_create_payment(order, PaymentMethod.COD, order.total_amount)
        payment.status = PaymentStatus.PENDING
        payment.save(update_fields=["status", "updated_at"])

        return {"payment_method": "cod", "payment": payment}

    # Online -> Cashfree
    if not settings.CASHFREE_APP_ID or not settings.CASHFREE_SECRET_KEY:
        raise ValueError("Online payment is not configured.")

    cf_order_id = f"{order.order_number}_{uuid.uuid4().hex[:10]}"

    logger.info(
        f"Creating Cashfree order: cf_order_id={cf_order_id}, "
        f"amount={order.total_amount}, user_id={user.id}"
    )

    try:
        cf_response = requests.post(
            f"{settings.CASHFREE_BASE_URL}/orders",
            headers={
                "x-client-id": settings.CASHFREE_APP_ID,
                "x-client-secret": settings.CASHFREE_SECRET_KEY,
                "x-api-version": settings.CASHFREE_API_VERSION,
                "Content-Type": "application/json",
            },
            json={
                "order_id": cf_order_id,
                "order_amount": float(order.total_amount),
                "order_currency": "INR",
                "customer_details": {
                    "customer_id": str(user.id),
                    "customer_phone": user.phone_number,
                    "customer_name": user.name or "Customer",
                },
            },
            timeout=15,
        )
    except requests.RequestException as e:
        raise ConnectionError(f"Could not reach payment gateway: {e}")

    if cf_response.status_code not in (200, 201):
        raise ValueError(f"Payment gateway error: {cf_response.text}")

    cf_order = cf_response.json()
    session_id = cf_order["payment_session_id"]

    order.payment_method = "online"
    order.cashfree_order_id = cf_order_id
    order.payment_session_id = session_id
    if order.payment_status == "failed":
        order.payment_status = "pending"
    order.save(
        update_fields=[
            "payment_method",
            "cashfree_order_id",
            "payment_session_id",
            "payment_status",
            "updated_at",
        ]
    )

    payment = _get_or_create_payment(order, PaymentMethod.ONLINE, order.total_amount)
    if payment.status == PaymentStatus.FAILED:
        payment.status = PaymentStatus.PENDING
        payment.save(update_fields=["status", "updated_at"])

    PaymentAttempt.objects.create(
        payment=payment,
        gateway=Gateway.CASHFREE,
        gateway_order_id=cf_order_id,
        payment_session_id=session_id,
        status=PaymentStatus.PENDING,
        amount=order.total_amount,
        gateway_response=cf_order,
    )

    return {
        "payment_method": "online",
        "payment_session_id": session_id,
        "cf_order_id": cf_order_id,
        "environment": settings.CASHFREE_ENV,
        "payment": payment,
    }


def verify_payment(order: Order) -> dict:
    """
    Verifies the payment with Cashfree.
    """
    if not order.cashfree_order_id:
        return {"payment_status": order.payment_status}

    try:
        cf_response = requests.get(
            f"{settings.CASHFREE_BASE_URL}/orders/{order.cashfree_order_id}",
            headers={
                "x-client-id": settings.CASHFREE_APP_ID,
                "x-client-secret": settings.CASHFREE_SECRET_KEY,
                "x-api-version": settings.CASHFREE_API_VERSION,
            },
            timeout=15,
        )
    except requests.RequestException as e:
        raise ConnectionError(f"Could not reach payment gateway: {e}")

    if cf_response.status_code != 200:
        raise ValueError(f"Payment gateway error: {cf_response.text}")

    cf_order = cf_response.json()
    order_status = cf_order.get("order_status")

    logger.info(
        f"Verified Cashfree payment: order_id={order.id}, "
        f"cf_order_id={order.cashfree_order_id}, status={order_status}"
    )

    if order_status == "PAID":
        gw_payment_id = str(cf_order.get("cf_order_id", ""))
        order.payment_status = "paid"
        order.payment_id = gw_payment_id
        order.save(update_fields=["payment_status", "payment_id", "updated_at"])

        if order.payment_record_id:
            payment = order.payment_record
            payment.mark_paid(gw_payment_id)
            PaymentAttempt.objects.filter(
                payment=payment,
                gateway_order_id=order.cashfree_order_id,
            ).update(
                status=PaymentStatus.PAID,
                gateway_payment_id=gw_payment_id,
            )

        return {"payment_status": "paid"}

    if order_status in ("EXPIRED", "TERMINATED"):
        order.payment_status = "failed"
        order.save(update_fields=["payment_status", "updated_at"])

        if order.payment_record_id:
            order.payment_record.mark_failed()
            PaymentAttempt.objects.filter(
                payment=order.payment_record,
                gateway_order_id=order.cashfree_order_id,
            ).update(status=PaymentStatus.FAILED)

    return {"payment_status": order.payment_status, "order_status": order_status}


def driver_initiate_payment(order: Order) -> dict:
    """
    Driver requests/generates a native UPI Intent QR for COD to Online conversion.
    """
    if order.payment_status == "paid":
        return {
            "upi_uri": "",
            "amount": float(order.total_amount),
            "order_number": order.order_number,
            "payment_status": "paid",
        }

    from app_config.models import SiteConfig
    import urllib.parse

    config = SiteConfig.get()
    merchant_upi_id = config.merchant_upi_id or "hdkfoods@axisbank"

    amount_str = f"{order.total_amount:.2f}".rstrip("0").rstrip(".")

    params = {
        "pa": merchant_upi_id,
        "pn": "HDK Foods",
        "am": amount_str,
        "cu": "INR",
        "tn": f"Order {order.order_number}",
    }
    upi_uri = (
        f"upi://pay?{urllib.parse.urlencode(params, quote_via=urllib.parse.quote)}"
    )

    order.payment_method = "online"
    order.save(update_fields=["payment_method", "updated_at"])

    payment = _get_or_create_payment(order, PaymentMethod.UPI, order.total_amount)
    PaymentAttempt.objects.create(
        payment=payment,
        gateway=Gateway.UPI_MANUAL,
        gateway_order_id=order.order_number,
        status=PaymentStatus.PENDING,
        amount=order.total_amount,
    )

    return {
        "upi_uri": upi_uri,
        "amount": float(order.total_amount),
        "order_number": order.order_number,
        "payment_status": order.payment_status,
        "payment": payment,
    }


def driver_verify_payment(order: Order) -> dict:
    """
    Driver marks payment as completed directly (bypassing UTR validation).
    """
    from django.utils import timezone

    driver_ref = f"verified_by_driver_{timezone.now().strftime('%Y%m%d%H%M%S')}"
    order.payment_status = "paid"
    order.payment_id = driver_ref
    order.payment_method = "online"
    order.save(
        update_fields=[
            "payment_status",
            "payment_id",
            "payment_method",
            "updated_at",
        ]
    )

    payment = _get_or_create_payment(order, PaymentMethod.UPI, order.total_amount)
    payment.mark_paid(driver_ref)
    attempt = payment.attempts.filter(
        gateway=Gateway.UPI_MANUAL, status=PaymentStatus.PENDING
    ).first()
    if attempt:
        attempt.status = PaymentStatus.PAID
        attempt.gateway_payment_id = driver_ref
        attempt.save(update_fields=["status", "gateway_payment_id", "updated_at"])
    else:
        PaymentAttempt.objects.create(
            payment=payment,
            gateway=Gateway.UPI_MANUAL,
            gateway_order_id=order.order_number,
            gateway_payment_id=driver_ref,
            status=PaymentStatus.PAID,
            amount=order.total_amount,
        )

    return {
        "payment_status": "paid",
        "payment_id": order.payment_id,
        "payment": payment,
    }


def _get_or_create_payment(order: Order, method: str, amount) -> Payment:
    """Return the Payment linked to this order, creating one if absent."""
    if order.payment_record_id:
        payment = order.payment_record
        payment.method = method
        payment.amount = amount
        payment.save(update_fields=["method", "amount", "updated_at"])
        return payment

    payment = Payment.objects.create(
        order=order,
        method=method,
        status=PaymentStatus.PENDING,
        amount=amount,
    )
    order.payment_record = payment
    order.save(update_fields=["payment_record"])
    return payment


def initiate_cashfree_refund(order: Order, reason: str) -> bool:
    """
    Initiates a Cashfree refund for the given order.
    """
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
            "Content-Type": "application/json",
        }
        payload = {
            "refund_amount": float(order.total_amount),
            "refund_id": refund_id,
            "refund_note": reason or "Cancellation refund",
        }
        res = requests.post(url, json=payload, headers=headers, timeout=10)
        if res.status_code in [200, 201]:
            return True
    except Exception as e:
        logger.warning(f"Refund initiation failed: {e}")
    return False
