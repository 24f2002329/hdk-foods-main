import logging
from django.http import JsonResponse
from django.db import connection
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync

logger = logging.getLogger(__name__)


def health_check(request):
    status = "healthy"
    details = {}
    http_status = 200

    # 1. Database Check
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
        details["database"] = {"status": "up"}
    except Exception as e:
        logger.error("Health check failed - Database offline: %s", e)
        status = "unhealthy"
        details["database"] = {"status": "down", "error": str(e)}
        http_status = 503

    # 2. Redis/Channels Check
    try:
        channel_layer = get_channel_layer()
        if channel_layer is not None:
            # Send and receive a dummy message or verify group add
            # For simplicity, we just verify channel layer exists and is initialized.
            # If using RedisChannelLayer, we can try to get redis connection
            if hasattr(channel_layer, "get_redis_connection"):
                # verify connection works
                async_to_sync(channel_layer.flush)()
            details["channels"] = {
                "status": "up",
                "backend": channel_layer.__class__.__name__,
            }
        else:
            details["channels"] = {"status": "not_configured"}
    except Exception as e:
        logger.error("Health check failed - Channel layer/Redis offline: %s", e)
        status = "unhealthy"
        details["channels"] = {"status": "down", "error": str(e)}
        http_status = 503

    # 3. System Metrics Check
    try:
        import psutil

        cpu = psutil.cpu_percent(interval=None)
        mem = psutil.virtual_memory()
        details["system"] = {
            "cpu_usage_percent": cpu,
            "memory_usage_percent": mem.percent,
            "memory_available_bytes": mem.available,
        }
    except ImportError:
        details["system"] = {"note": "psutil not installed, system metrics unavailable"}

    return JsonResponse({"status": status, "details": details}, status=http_status)
