from django.urls import path
from .views import (
    CategoryListView,
    ProductListView,
    ProductToggleAvailabilityView,
    ProductCreateView,
    ProductUpdateView,
    ProductDeleteView,
)

urlpatterns = [
    path("categories/", CategoryListView.as_view()),
    path("products/", ProductListView.as_view()),
    path("products/create/", ProductCreateView.as_view()),
    path("products/<int:pk>/toggle/", ProductToggleAvailabilityView.as_view()),
    path("products/<int:pk>/update/", ProductUpdateView.as_view()),
    path("products/<int:pk>/delete/", ProductDeleteView.as_view()),
]