from django.db import models


class Category(models.Model):
    name = models.CharField(max_length=100)
    image = models.URLField(blank=True)

    def __str__(self):
        return self.name


class Product(models.Model):
    category = models.ForeignKey(
        Category,
        on_delete=models.CASCADE,
        related_name="products"
    )

    name = models.CharField(max_length=200)

    description = models.TextField(
        blank=True
    )

    price = models.DecimalField(
        max_digits=10,
        decimal_places=2
    )

    image = models.URLField(
        blank=True
    )

    is_available = models.BooleanField(
        default=True
    )

    is_featured = models.BooleanField(
        default=False
    )

    # Add-on / extra items (e.g. Coke, Juice) offered as checkboxes in the
    # cart. Excluded from the main menu and featured lists.
    is_addon = models.BooleanField(
        default=False
    )

    preparation_time = models.PositiveIntegerField(
        default=15
    )

    rating = models.DecimalField(
        max_digits=2,
        decimal_places=1,
        default=0
    )

    # Custom promotional badge shown on product card (e.g., '15% OFF', 'Best Seller')
    promo_tag = models.CharField(
        max_length=50,
        blank=True,
        default="",
        help_text="Custom promo badge text (e.g. '15% OFF', 'BOGO', 'Chef Special')."
    )

    # Strike price (original price) shown as crossed-out in UI.
    strike_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Original price before discount (slashed). Leave blank if no discount."
    )

    created_at = models.DateTimeField(
        auto_now_add=True
    )

    def __str__(self):
        return self.name