import firebase_admin
import json
import os

from firebase_admin import credentials

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