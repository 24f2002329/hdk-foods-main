from django.contrib import admin
from .models import SiteConfig, Banner


@admin.register(SiteConfig)
class SiteConfigAdmin(admin.ModelAdmin):
    list_display = ("__str__", "is_store_open", "store_open_time", "store_close_time")
    list_editable = ("is_store_open", "store_open_time", "store_close_time")


@admin.register(Banner)
class BannerAdmin(admin.ModelAdmin):
    list_display = ("title", "subtitle", "is_active", "order")
    list_editable = ("is_active", "order")
    list_filter = ("is_active",)
