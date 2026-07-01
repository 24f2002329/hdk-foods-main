from django.db import models
from accounts.models import User

class OrderMessage(models.Model):
    order = models.ForeignKey(
        "orders.Order",
        on_delete=models.CASCADE,
        related_name="messages"
    )
    sender = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name="sent_messages"
    )
    message = models.TextField()
    is_admin = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = "orders_ordermessage"

    def __str__(self):
        return f"Msg {self.id} on {self.order.order_number} by {self.sender.phone_number}"
