import logging
from rest_framework.throttling import SimpleRateThrottle

logger = logging.getLogger(__name__)


class RoleBasedRateThrottle(SimpleRateThrottle):
    """
    Dynamically throttles requests depending on the user's role:
    - Admin/Staff: 2000 requests / minute
    - Delivery Partner: 180 requests / minute (allows higher frequency updates)
    - Customer: 60 requests / minute
    - Anonymous: 30 requests / minute
    """

    scope = "role_based"

    def __init__(self):
        # Set a default rate first so super().__init__() doesn't raise ImproperlyConfigured
        self.rate = "60/min"
        super().__init__()

    def get_cache_key(self, request, view):
        if request.user and request.user.is_authenticated:
            role = getattr(request.user, "role", "customer")
            ident = f"auth_{request.user.id}_{role}"
        else:
            ident = f"anon_{self.get_ident(request)}"

        return self.cache_format % {"scope": self.scope, "ident": ident}

    def get_rate_for_request(self, request):
        if not request or not request.user or not request.user.is_authenticated:
            return "30/min"

        if (
            request.user.is_staff
            or getattr(request.user, "role", "customer") == "admin"
        ):
            return "2000/min"

        role = getattr(request.user, "role", "customer")
        if role == "delivery":
            return "180/min"

        return "60/min"

    def allow_request(self, request, view):
        # Dynamically set the rate depending on the request's user context
        self.rate = self.get_rate_for_request(request)
        self.num_requests, self.duration = self.parse_rate(self.rate)

        return super().allow_request(request, view)
