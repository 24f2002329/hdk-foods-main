from django.contrib import admin
from .models import PrepConfig


@admin.register(PrepConfig)
class PrepConfigAdmin(admin.ModelAdmin):
    list_display = ("__str__", "queue_multiplier", "rush_hour_bonus", "override_boost")
