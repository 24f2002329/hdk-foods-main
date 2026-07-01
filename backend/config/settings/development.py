"""
config/settings/development.py
─────────────────────────────────────────────────────────────────────────────
Development settings.  Activates debug mode, relaxed CORS, verbose logging,
and falls back to SQLite when no DATABASE_URL is set.

Usage:
    DJANGO_SETTINGS_MODULE=config.settings.development python manage.py runserver
"""

from .base import *  # noqa: F401, F403

DEBUG = True

SECRET_KEY = os.getenv(  # noqa: F405
    "SECRET_KEY", "django-insecure-dev-only-key-do-not-use-in-prod"
)

ALLOWED_HOSTS = ["*"]

# Allow all CORS in dev so the Flutter emulator can hit the server
CORS_ALLOW_ALL_ORIGINS = True

# Louder logging for easier debugging
LOGGING["root"]["level"] = "DEBUG"  # noqa: F405

# django-axes: more lenient lockout in development
AXES_FAILURE_LIMIT = 20
