from django.db import models
from accounts.models import User

class CoinTransaction(models.Model):
    TRANSACTION_TYPES = [
        ('earned', 'Earned'),
        ('redeemed', 'Redeemed'),
        ('reversed', 'Reversed'),
    ]

    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="coin_transactions"
    )
    amount = models.IntegerField()
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_TYPES)
    description = models.CharField(max_length=255, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.user.phone_number} - {self.amount} ({self.transaction_type})"
