from django.urls import path, include
from rest_framework.routers import DefaultRouter
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
    ModifierGroupViewSet,
    ModifierOptionViewSet,
)

router = DefaultRouter()
router.register("modifiers/groups", ModifierGroupViewSet, basename="modifier-groups")
router.register("modifiers/options", ModifierOptionViewSet, basename="modifier-options")

urlpatterns = [
    path("", include(router.urls)),
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