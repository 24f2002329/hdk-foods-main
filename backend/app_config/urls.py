from django.urls import path
from .views import (
    BannerDetailView,
    BannerListView,
    BroadcastNotificationView,
    SiteConfigView,
    BannerImageUploadView,
    NotificationListView,
    MarkNotificationReadView,
)

urlpatterns = [
    path("config/", SiteConfigView.as_view()),
    path("config/banners/", BannerListView.as_view()),
    path("config/banners/<int:pk>/", BannerDetailView.as_view()),
    path("config/banners/<int:pk>/upload-image/", BannerImageUploadView.as_view()),
    path("config/notify-all/", BroadcastNotificationView.as_view()),
    path("config/notifications/", NotificationListView.as_view()),
    path("config/notifications/<int:pk>/read/", MarkNotificationReadView.as_view()),
]
