from django.db import models


class Category(models.Model):
    name = models.CharField(max_length=100)
    image = models.URLField(blank=True)

    def __str__(self):
        return self.name


class Product(models.Model):
    category = models.ForeignKey(
        Category, on_delete=models.CASCADE, related_name="products"
    )

    name = models.CharField(max_length=200)

    description = models.TextField(blank=True)

    price = models.DecimalField(max_digits=10, decimal_places=2)

    image = models.URLField(blank=True)

    is_available = models.BooleanField(default=True)

    is_featured = models.BooleanField(default=False)

    # Add-on / extra items (e.g. Coke, Juice) offered as checkboxes in the
    # cart. Excluded from the main menu and featured lists.
    is_addon = models.BooleanField(default=False)

    preparation_time = models.PositiveIntegerField(default=15)

    base_prep_minutes = models.PositiveIntegerField(
        default=15, help_text="Base preparation time in minutes for this dish."
    )

    rating = models.DecimalField(max_digits=2, decimal_places=1, default=0)

    # Custom promotional badge shown on product card (e.g., '15% OFF', 'Best Seller')
    promo_tag = models.CharField(
        max_length=50,
        blank=True,
        default="",
        help_text="Custom promo badge text (e.g. '15% OFF', 'BOGO', 'Chef Special').",
    )

    # Strike price (original price) shown as crossed-out in UI.
    strike_price = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        null=True,
        blank=True,
        help_text="Original price before discount (slashed). Leave blank if no discount.",
    )

    modifier_groups = models.ManyToManyField(
        "ModifierGroup", related_name="products", blank=True
    )

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class ModifierGroup(models.Model):
    name = models.CharField(max_length=100)
    selection_type = models.CharField(
        max_length=10,
        choices=[("SINGLE", "Single Choice"), ("MULTIPLE", "Multiple Choice")],
        default="SINGLE",
    )
    required = models.BooleanField(default=False)
    min_selection = models.PositiveIntegerField(default=0)
    max_selection = models.PositiveIntegerField(default=1)
    display_order = models.PositiveIntegerField(default=0)
    visibility = models.BooleanField(default=True)
    description = models.TextField(blank=True, default="")

    def __str__(self):
        return self.name


class ModifierOption(models.Model):
    modifier_group = models.ForeignKey(
        ModifierGroup, on_delete=models.CASCADE, related_name="options"
    )
    name = models.CharField(max_length=100)
    extra_price = models.DecimalField(max_digits=10, decimal_places=2, default=0.00)
    is_available = models.BooleanField(default=True)
    image = models.URLField(blank=True, default="")
    sort_order = models.PositiveIntegerField(default=0)

    def __str__(self):
        return f"{self.modifier_group.name} - {self.name}"


class ProductModifierOptionOverride(models.Model):
    product = models.ForeignKey(
        Product, on_delete=models.CASCADE, related_name="price_overrides"
    )
    modifier_option = models.ForeignKey(
        ModifierOption, on_delete=models.CASCADE, related_name="product_overrides"
    )
    extra_price = models.DecimalField(max_digits=10, decimal_places=2)

    class Meta:
        unique_together = ("product", "modifier_option")

    def __str__(self):
        return f"{self.product.name} - {self.modifier_option.name} Override (₹{self.extra_price})"
