from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    MeView,
    StaffLoginView,
    VerifyOTPView
)

urlpatterns = [
    path("staff-login/", StaffLoginView.as_view()),
    path("me/", MeView.as_view()),
    path("verify-otp/", VerifyOTPView.as_view()),
    path("token/refresh/", TokenRefreshView.as_view()),
]