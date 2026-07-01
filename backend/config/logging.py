import json
import logging
import datetime
import contextvars
from django.utils.deprecation import MiddlewareMixin

_log_context = contextvars.ContextVar("log_context", default={})


def bind_log_context(**kwargs):
    """Bind key-value pairs to the current thread-safe log context."""
    ctx = _log_context.get().copy()
    ctx.update(kwargs)
    _log_context.set(ctx)


def unbind_log_context(*keys):
    """Remove key-value pairs from the current log context."""
    ctx = _log_context.get().copy()
    for key in keys:
        ctx.pop(key, None)
    _log_context.set(ctx)


def clear_log_context():
    """Clear all values from the current log context."""
    _log_context.set({})


class StructuredJSONFormatter(logging.Formatter):
    """Custom logging formatter that outputs log messages in JSON format,
    guaranteeing that structured fields (order_id, customer, payment,
    delivery_partner, status) are always present in the log output.
    """

    def format(self, record):
        if self.usesTime():
            record_time = self.formatTime(record, self.datefmt)
        else:
            record_time = datetime.datetime.fromtimestamp(record.created).isoformat()

        # Base log fields
        log_data = {
            "timestamp": record_time,
            "level": record.levelname,
            "logger": record.name,
            "message": record.getMessage(),
        }

        if record.exc_info:
            log_data["exception"] = self.formatException(record.exc_info)
        if record.stack_info:
            log_data["stack_trace"] = self.formatStack(record.stack_info)

        # Get active context-based log fields
        ctx = _log_context.get()

        # Target structured fields that must be present inside every log
        structured_fields = [
            "order_id",
            "customer",
            "payment",
            "delivery_partner",
            "status",
        ]
        for field in structured_fields:
            # Lookup precedence:
            # 1. Attribute on logging record (passed via extra={'field': value})
            # 2. Key in thread-safe contextvars context
            # 3. Default to None (renders as null in JSON)
            val = getattr(record, field, ctx.get(field, None))
            log_data[field] = self._serialize_field(val)

        # Additional extra fields
        standard_attrs = {
            "args",
            "asctime",
            "created",
            "exc_info",
            "exc_text",
            "filename",
            "funcName",
            "levelname",
            "levelno",
            "lineno",
            "module",
            "msecs",
            "message",
            "msg",
            "name",
            "pathname",
            "process",
            "processName",
            "relativeCreated",
            "stack_info",
            "thread",
            "threadName",
        }

        extra_data = {}
        # Merge other attributes from ContextVar
        for key, val in ctx.items():
            if key not in structured_fields:
                extra_data[key] = self._serialize_field(val)

        # Merge other attributes from record.__dict__ (passed via extra=...)
        for key, val in record.__dict__.items():
            if key not in standard_attrs and key not in structured_fields:
                extra_data[key] = self._serialize_field(val)

        if extra_data:
            log_data["extra"] = extra_data

        return json.dumps(log_data)

    def _serialize_field(self, val):
        if val is None:
            return None
        if isinstance(val, (int, float, bool, str, dict, list)):
            return val
        # Retrieve primary key/ID from Django model instance
        if hasattr(val, "id"):
            return val.id
        if hasattr(val, "pk"):
            return val.pk
        return str(val)


class LogContextMiddleware(MiddlewareMixin):
    """Middleware to manage structured logging context.
    Clears the context before and after requests, and automatically binds the authenticated
    user ID depending on their role.
    """

    def process_request(self, request):
        clear_log_context()

    def process_view(self, request, view_func, view_args, view_kwargs):
        # Automatically bind authenticated customer or delivery partner ID to log context
        if request.user and request.user.is_authenticated:
            role = getattr(request.user, "role", "customer")
            if role == "delivery":
                bind_log_context(delivery_partner=request.user.id)
            elif role == "customer":
                bind_log_context(customer=request.user.id)
        return None

    def process_response(self, request, response):
        clear_log_context()
        return response

    def process_exception(self, request, exception):
        clear_log_context()
