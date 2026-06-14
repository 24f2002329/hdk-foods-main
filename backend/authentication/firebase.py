import firebase_admin
import json
import logging
import os

from firebase_admin import credentials, messaging

logger = logging.getLogger(__name__)

if not firebase_admin._apps:

    firebase_json = os.environ.get(
        "FIREBASE_SERVICE_ACCOUNT"
    )

    if not firebase_json:
        print("Warning: FIREBASE_SERVICE_ACCOUNT environment variable is not set.")
    else:
        try:
            cred = credentials.Certificate(
                json.loads(firebase_json)
            )
            firebase_admin.initialize_app(cred)
        except json.JSONDecodeError as e:
            raise ValueError(f"FIREBASE_SERVICE_ACCOUNT is not a valid JSON string. Please check your .env file. Error: {e}")


def send_push(user, title: str, body: str, data: dict = None):
    """Send a push notification to a single user. Silently skips if no token or Firebase not configured."""
    if not firebase_admin._apps:
        return
    token = getattr(user, "fcm_token", "").strip()
    if not token:
        return
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
        )
        messaging.send(message)
    except Exception as e:
        logger.warning("FCM send failed for user %s: %s", user.pk, e)


def send_push_to_all(title: str, body: str, data: dict = None) -> int:
    """Broadcast a push notification to all users with an FCM token. Returns count sent."""
    if not firebase_admin._apps:
        return 0
    from accounts.models import User
    tokens = list(User.objects.exclude(fcm_token="").values_list("fcm_token", flat=True))
    if not tokens:
        return 0
    # FCM multicast accepts up to 500 tokens per call
    sent = 0
    for i in range(0, len(tokens), 500):
        batch = tokens[i:i + 500]
        try:
            message = messaging.MulticastMessage(
                notification=messaging.Notification(title=title, body=body),
                data={k: str(v) for k, v in (data or {}).items()},
                tokens=batch,
            )
            response = messaging.send_each_for_multicast(message)
            sent += response.success_count
        except Exception as e:
            logger.warning("FCM broadcast batch failed: %s", e)
    return sent