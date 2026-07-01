from django.urls import path

from .views import (
    MeView,
    StaffLoginView,
    VerifyOTPView,
    SendSMSView,
    CookieTokenRefreshView,
    LogoutView,
)

urlpatterns = [
    path("staff-login/", StaffLoginView.as_view()),
    path("me/", MeView.as_view()),
    path("verify-otp/", VerifyOTPView.as_view()),
    path("send-sms/", SendSMSView.as_view()),
    path("logout/", LogoutView.as_view()),
    path("token/refresh/", CookieTokenRefreshView.as_view()),
]
