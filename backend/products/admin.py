from django.contrib import admin
from .models import Category, Product

admin.site.register(Category)


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("name", "category", "price", "rating", "is_available")
    list_editable = ("rating", "is_available")
    list_filter = ("category", "is_available", "is_featured")
    search_fields = ("name",)
