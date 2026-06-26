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
        print("Warning: FIREBASE_SERVICE_ACCOUNT environment variable is not set.")
    else:
        try:
            firebase_data = json.loads(firebase_json)
            cred = credentials.Certificate(firebase_data)
            
            project_id = firebase_data.get("project_id")
            storage_bucket = os.environ.get("FIREBASE_STORAGE_BUCKET")
            if not storage_bucket and project_id:
                storage_bucket = f"{project_id}.firebasestorage.app"
                
            firebase_admin.initialize_app(cred, {
                'storageBucket': storage_bucket
            })
        except json.JSONDecodeError as e:
            raise ValueError(f"FIREBASE_SERVICE_ACCOUNT is not a valid JSON string. Please check your .env file. Error: {e}")


def _upload_to_bucket(bucket, file_obj, destination_path: str) -> str:
    blob = bucket.blob(destination_path)
    
    # Reset file pointer to beginning
    file_obj.seek(0)
    
    # Upload file content
    blob.upload_from_file(
        file_obj,
        content_type=file_obj.content_type or "image/jpeg"
    )
    
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
        if "bucket does not exist" in str(e).lower() and bucket.name.endswith(".firebasestorage.app"):
            new_bucket_name = bucket.name.replace(".firebasestorage.app", ".appspot.com")
            logger.info("Default .firebasestorage.app bucket not found. Retrying with older domain: %s", new_bucket_name)
            try:
                new_bucket = storage.bucket(new_bucket_name)
                return _upload_to_bucket(new_bucket, file_obj, destination_path)
            except Exception as retry_e:
                raise retry_e
        raise e


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


def send_push_to_role(role: str, title: str, body: str, data: dict = None):
    """Send push to all users of the given role who have an FCM token."""
    if not firebase_admin._apps:
        return
    from accounts.models import User
    for user in User.objects.filter(role=role).exclude(fcm_token=""):
        send_push(user, title, body, data)


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