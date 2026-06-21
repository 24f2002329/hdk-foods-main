from django.urls import path
from .views import (
    AddOnListView,
    CategoryDetailView,
    CategoryListView,
    FeaturedProductsView,
    ProductImageUploadView,
    ProductListView,
    ProductToggleAvailabilityView,
    ProductCreateView,
    ProductUpdateView,
    ProductDeleteView,
)

urlpatterns = [
    path("categories/", CategoryListView.as_view()),
    path("categories/<int:pk>/", CategoryDetailView.as_view()),
    path("products/", ProductListView.as_view()),
    path("products/addons/", AddOnListView.as_view()),
    path("products/featured/", FeaturedProductsView.as_view()),
    path("products/create/", ProductCreateView.as_view()),
    path("products/<int:pk>/toggle/", ProductToggleAvailabilityView.as_view()),
    path("products/<int:pk>/update/", ProductUpdateView.as_view()),
    path("products/<int:pk>/delete/", ProductDeleteView.as_view()),
    path("products/<int:pk>/image/", ProductImageUploadView.as_view()),
]