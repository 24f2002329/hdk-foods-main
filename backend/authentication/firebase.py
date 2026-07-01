import firebase_admin
import json
import logging
import os
import urllib.parse

from firebase_admin import credentials, messaging, storage

logger = logging.getLogger(__name__)

if not firebase_admin._apps:
    firebase_json = os.environ.get("FIREBASE_SERVICE_ACCOUNT")
    if not firebase_json:
        logger.warning("FIREBASE_SERVICE_ACCOUNT environment variable is not set.")
    else:
        try:
            firebase_data = json.loads(firebase_json)
            cred = credentials.Certificate(firebase_data)

            project_id = firebase_data.get("project_id")
            storage_bucket = os.environ.get("FIREBASE_STORAGE_BUCKET")
            if not storage_bucket and project_id:
                storage_bucket = f"{project_id}.firebasestorage.app"

            firebase_admin.initialize_app(cred, {"storageBucket": storage_bucket})
        except json.JSONDecodeError as e:
            raise ValueError(
                f"FIREBASE_SERVICE_ACCOUNT is not a valid JSON string. Please check your .env file. Error: {e}"
            )


def _upload_to_bucket(bucket, file_obj, destination_path: str) -> str:
    blob = bucket.blob(destination_path)

    # Reset file pointer to beginning
    file_obj.seek(0)

    # Upload file content
    blob.upload_from_file(file_obj, content_type=file_obj.content_type or "image/jpeg")

    try:
        # Try to make public (works on fine-grained access control buckets)
        blob.make_public()
        return blob.public_url
    except Exception as e:
        logger.warning("Could not set ACL (uniform bucket-level access enabled): %s", e)
        # Use Firebase public download URL format as fallback
        encoded_path = urllib.parse.quote(destination_path, safe="")
        return f"https://firebasestorage.googleapis.com/v0/b/{bucket.name}/o/{encoded_path}?alt=media"


def upload_file_to_firebase(file_obj, destination_path: str) -> str:
    """Uploads a file to Firebase Storage and returns its public URL."""
    if not firebase_admin._apps:
        raise ValueError("Firebase is not initialized.")

    bucket = storage.bucket()
    try:
        return _upload_to_bucket(bucket, file_obj, destination_path)
    except Exception as e:
        # If the default bucket does not exist and ends with .firebasestorage.app,
        # try the older .appspot.com domain format.
        if "bucket does not exist" in str(e).lower() and bucket.name.endswith(
            ".firebasestorage.app"
        ):
            new_bucket_name = bucket.name.replace(
                ".firebasestorage.app", ".appspot.com"
            )
            logger.info(
                "Default .firebasestorage.app bucket not found. Retrying with older domain: %s",
                new_bucket_name,
            )
            try:
                new_bucket = storage.bucket(new_bucket_name)
                return _upload_to_bucket(new_bucket, file_obj, destination_path)
            except Exception as retry_e:
                raise retry_e
        raise e


def _create_notification_log(
    *,
    title: str,
    body: str,
    data: dict = None,
    user=None,
    notification=None,
    token: str = "",
    target_role: str = "",
    priority: str = "normal",
):
    try:
        from notifications.models import NotificationLog

        return NotificationLog.objects.create(
            notification=notification,
            user=user,
            target_role=target_role,
            title=title,
            body=body,
            data=data or {},
            token=token,
            priority=priority,
        )
    except Exception as e:
        logger.warning("Failed to create notification log: %s", e)
        return None


def _update_notification_log(log, **fields):
    if not log:
        return
    try:
        for field, value in fields.items():
            setattr(log, field, value)
        log.save(update_fields=[*fields.keys(), "updated_at"])
    except Exception as e:
        logger.warning("Failed to update notification log: %s", e)


def send_push(user, title: str, body: str, data: dict = None, priority: str = "normal"):
    """Send a push notification to a single user and record delivery status."""
    notification = None
    try:
        from notifications.models import Notification

        notification = Notification.objects.create(
            user=user, title=title, body=body, priority=priority
        )
    except Exception as e:
        logger.warning("Failed to save database notification: %s", e)

    token = getattr(user, "fcm_token", "").strip()
    log = _create_notification_log(
        user=user,
        notification=notification,
        title=title,
        body=body,
        data=data,
        token=token,
        priority=priority,
    )

    if not firebase_admin._apps:
        _update_notification_log(
            log,
            status="skipped",
            error="Firebase is not configured.",
        )
        return
    if not token:
        _update_notification_log(log, status="skipped", error="User has no FCM token.")
        return
    try:
        from django.utils import timezone

        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            token=token,
        )
        message_id = messaging.send(message)
        _update_notification_log(
            log,
            status="sent",
            attempts=1,
            fcm_message_id=message_id,
            sent_at=timezone.now(),
            error="",
        )
    except Exception as e:
        _update_notification_log(log, status="failed", attempts=1, error=str(e))
        logger.warning("FCM send failed for user %s: %s", user.pk, e)


def send_push_to_role(
    role: str, title: str, body: str, data: dict = None, priority: str = "normal"
):
    """Send push to all users of the given role who have an FCM token."""
    if not firebase_admin._apps:
        _update_notification_log(
            _create_notification_log(
                target_role=role,
                title=title,
                body=body,
                data=data,
                priority=priority,
            ),
            status="skipped",
            error="Firebase is not configured.",
        )
        return
    from accounts.models import User

    for user in User.objects.filter(role=role).exclude(fcm_token=""):
        send_push(user, title, body, data, priority=priority)


def send_push_to_all(
    title: str,
    body: str,
    data: dict = None,
    notification=None,
    priority: str = "normal",
) -> int:
    """Broadcast a push notification to all users with an FCM token. Returns count sent."""
    if not firebase_admin._apps:
        _update_notification_log(
            _create_notification_log(
                notification=notification,
                title=title,
                body=body,
                data=data,
                priority=priority,
            ),
            status="skipped",
            error="Firebase is not configured.",
        )
        return 0
    from accounts.models import User
    from django.utils import timezone

    users = list(User.objects.exclude(fcm_token="").only("id", "fcm_token"))
    if not users:
        _update_notification_log(
            _create_notification_log(
                notification=notification,
                title=title,
                body=body,
                data=data,
                priority=priority,
            ),
            status="skipped",
            error="No users with FCM tokens.",
        )
        return 0

    sent = 0
    for i in range(0, len(users), 500):
        batch_users = users[i : i + 500]
        batch_tokens = [user.fcm_token for user in batch_users]
        batch_logs = [
            _create_notification_log(
                user=user,
                notification=notification,
                title=title,
                body=body,
                data=data,
                token=user.fcm_token,
                priority=priority,
            )
            for user in batch_users
        ]
        try:
            message = messaging.MulticastMessage(
                notification=messaging.Notification(title=title, body=body),
                data={k: str(v) for k, v in (data or {}).items()},
                tokens=batch_tokens,
            )
            response = messaging.send_each_for_multicast(message)
            sent += response.success_count
            for log, result in zip(batch_logs, response.responses):
                if result.success:
                    _update_notification_log(
                        log,
                        status="sent",
                        attempts=1,
                        fcm_message_id=result.message_id or "",
                        sent_at=timezone.now(),
                        error="",
                    )
                else:
                    _update_notification_log(
                        log,
                        status="failed",
                        attempts=1,
                        error=str(result.exception),
                    )
        except Exception as e:
            for log in batch_logs:
                _update_notification_log(log, status="failed", attempts=1, error=str(e))
            logger.warning("FCM broadcast batch failed: %s", e)
    return sent
