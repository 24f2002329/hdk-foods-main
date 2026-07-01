from datetime import time
from django.db import models

class PrepConfig(models.Model):
    queue_multiplier = models.FloatField(default=2.0, help_text="Minutes added per active order in the queue")
    rush_hour_bonus = models.PositiveIntegerField(default=5, help_text="Extra minutes added during peak hours")
    override_boost = models.IntegerField(default=0, help_text="Manual override minutes added to all predictions")

    peak_start_time = models.TimeField(default=time(18, 0))
    peak_end_time = models.TimeField(default=time(22, 0))
    peak_weekdays = models.CharField(max_length=50, default="4,5,6", help_text="Comma-separated weekdays for peak hours (0=Mon, 6=Sun)")

    class Meta:
        db_table = "orders_prepconfig"
        verbose_name = "Preparation Configuration"

    def __str__(self):
        return "Prep Configuration"

    @classmethod
    def get(cls):
        obj, _ = cls.objects.get_or_create(pk=1)
        return obj
