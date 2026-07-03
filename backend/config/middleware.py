import logging
import traceback
from django.http import JsonResponse
from django.conf import settings
from django.utils.deprecation import MiddlewareMixin

logger = logging.getLogger(__name__)


class FriendlyExceptionMiddleware(MiddlewareMixin):
    """Catches unhandled exceptions for API endpoints and returns a clean,
    well-structured JSON response instead of default HTML pages.
    """

    def process_exception(self, request, exception):
        # We only want to handle API requests
        is_api = (
            request.path.startswith("/api/")
            or "application/json" in request.headers.get("Accept", "").lower()
        )

        if not is_api:
            # Let standard Django exception handling run for HTML views
            return None

        # Log the traceback so we don't lose the error details
        logger.exception("Unhandled Exception occurred on API request: %s", exception)

        # Get request_id if available
        request_id = getattr(request, "request_id", "unknown")

        error_data = {
            "error": {
                "message": "A temporary server error occurred. Please try again shortly.",
                "code": "INTERNAL_SERVER_ERROR",
                "request_id": request_id,
            }
        }

        # Include debug information if in DEBUG mode
        if settings.DEBUG:
            error_data["error"]["debug_message"] = str(exception)
            error_data["error"]["traceback"] = traceback.format_exc().split("\n")

        return JsonResponse(error_data, status=500)


class SecurityHeadersMiddleware(MiddlewareMixin):
    """Adds security-hardening headers (CSP, HSTS, Referrer-Policy) to responses."""

    def process_response(self, request, response):
        response["Content-Security-Policy"] = (
            "default-src 'self'; "
            "script-src 'self' 'unsafe-inline' 'unsafe-eval'; "
            "style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; "
            "font-src 'self' https://fonts.gstatic.com; "
            "img-src 'self' data: https://firebasestorage.googleapis.com https://*.firebasestorage.app; "
            "connect-src 'self' wss: ws: https:;"
        )
        response["X-Content-Type-Options"] = "nosniff"
        response["X-Frame-Options"] = "DENY"
        response["Referrer-Policy"] = "strict-origin-when-cross-origin"
        return response
