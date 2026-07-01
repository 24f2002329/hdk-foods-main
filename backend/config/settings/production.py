"""
config/settings/production.py
─────────────────────────────────────────────────────────────────────────────
Production settings for Azure App Service (and any other live host).

All secrets MUST come from environment variables — never hardcoded here.

Usage:
    DJANGO_SETTINGS_MODULE=config.settings.production  (set in App Service config)
"""

from .base import *  # noqa: F401, F403

DEBUG = False

# SECRET_KEY must be set in the environment — raise immediately if missing.
import os as _os  # noqa: E402

_secret = _os.getenv("SECRET_KEY")
if not _secret or _secret.startswith("django-insecure"):
    raise RuntimeError(
        "SECRET_KEY environment variable is missing or is still the insecure default. "
        "Set a strong random key before running in production."
    )
SECRET_KEY = _secret

# ─── Hosts & CSRF ─────────────────────────────────────────────────────────────

ALLOWED_HOSTS = _os.getenv("ALLOWED_HOSTS", "").split(",")

# Azure App Service: add WEBSITE_HOSTNAME and allow internal health-check IPs.
if _os.getenv("WEBSITE_INSTANCE_ID"):
    _azure_hostname = _os.getenv("WEBSITE_HOSTNAME")
    if _azure_hostname and _azure_hostname not in ALLOWED_HOSTS:
        ALLOWED_HOSTS.append(_azure_hostname)

    class _AzureAllowedHosts(list):
        def __iter__(self):
            import inspect

            frame = inspect.currentframe()
            try:
                while frame:
                    if frame.f_code.co_name in ("validate_host", "<genexpr>"):
                        f = frame
                        while f:
                            if f.f_code.co_name == "validate_host":
                                host = f.f_locals.get("host", "")
                                if host and host.split(":")[0].startswith("169.254."):
                                    return iter(["*"])
                                break
                            f = f.f_back
                        break
                    frame = frame.f_back
            except Exception:
                pass
            return super().__iter__()

    ALLOWED_HOSTS = _AzureAllowedHosts(ALLOWED_HOSTS)

CSRF_TRUSTED_ORIGINS = (
    _os.getenv("CSRF_TRUSTED_ORIGINS", "").split(",")
    if _os.getenv("CSRF_TRUSTED_ORIGINS")
    else []
)

# ─── Media root (persistent Azure volume) ─────────────────────────────────────

if _os.getenv("WEBSITE_INSTANCE_ID"):
    from pathlib import Path as _Path  # noqa: E402

    MEDIA_ROOT = _Path("/home/site/media")

# ─── Security hardening ───────────────────────────────────────────────────────

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = True
SESSION_COOKIE_SECURE = True
CSRF_COOKIE_SECURE = True
SECURE_HSTS_SECONDS = 31536000          # 1 year
SECURE_HSTS_INCLUDE_SUBDOMAINS = True
SECURE_HSTS_PRELOAD = True
SECURE_CONTENT_TYPE_NOSNIFF = True
