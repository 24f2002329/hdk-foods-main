from django.urls import path
from .views import (
    CategoryListView,
    ProductListView,
    ProductToggleAvailabilityView,
)

urlpatterns = [
    path("categories/", CategoryListView.as_view()),
    path("products/", ProductListView.as_view()),
    path("products/<int:pk>/toggle/", ProductToggleAvailabilityView.as_view()),
]