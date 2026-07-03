"""
URL configuration for config project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""

from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.views.static import serve

from django.http import JsonResponse
from config.health import health_check as detailed_health_check


def simple_health_check(request):
    return JsonResponse({"status": "healthy"})


urlpatterns = [
    path("", simple_health_check, name="health_check"),
    path("health/", detailed_health_check, name="detailed_health_check"),
    path("admin/", admin.site.urls),
    path("api/v1/", include("products.urls")),
    path("api/v1/orders/", include("orders.urls")),
    path("api/v1/auth/", include("authentication.urls")),
    path("api/v1/", include("accounts.urls")),
    path("api/v1/", include("app_config.urls")),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# Manual routing to serve media and static files when DEBUG = False in production
urlpatterns += [
    re_path(r"^media/(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}),
    re_path(r"^static/(?P<path>.*)$", serve, {"document_root": settings.STATIC_ROOT}),
]
