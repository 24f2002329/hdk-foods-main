from django.urls import path
from .views import (
    BannerDetailView,
    BannerListView,
    BroadcastNotificationView,
    SiteConfigView,
)

urlpatterns = [
    path("config/", SiteConfigView.as_view()),
    path("config/banners/", BannerListView.as_view()),
    path("config/banners/<int:pk>/", BannerDetailView.as_view()),
    path("config/notify-all/", BroadcastNotificationView.as_view()),
]
