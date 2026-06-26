from django.contrib import admin
from .models import Category, Product, ModifierGroup, ModifierOption, ProductModifierOptionOverride

admin.site.register(Category)


class ModifierOptionInline(admin.TabularInline):
    model = ModifierOption
    extra = 1


@admin.register(ModifierGroup)
class ModifierGroupAdmin(admin.ModelAdmin):
    list_display = ("name", "selection_type", "required", "min_selection", "max_selection", "display_order", "visibility")
    list_filter = ("selection_type", "required", "visibility")
    search_fields = ("name",)
    inlines = [ModifierOptionInline]


@admin.register(ModifierOption)
class ModifierOptionAdmin(admin.ModelAdmin):
    list_display = ("name", "modifier_group", "extra_price", "is_available", "sort_order")
    list_filter = ("modifier_group", "is_available")
    search_fields = ("name", "modifier_group__name")


@admin.register(ProductModifierOptionOverride)
class ProductModifierOptionOverrideAdmin(admin.ModelAdmin):
    list_display = ("product", "modifier_option", "extra_price")
    list_filter = ("product", "modifier_option__modifier_group")
    search_fields = ("product__name", "modifier_option__name")


@admin.register(Product)
class ProductAdmin(admin.ModelAdmin):
    list_display = ("name", "category", "price", "strike_price", "promo_tag", "rating", "is_available", "is_featured")
    list_editable = ("rating", "is_available", "is_featured", "promo_tag", "strike_price")
    list_filter = ("category", "is_available", "is_featured")
    search_fields = ("name",)
    filter_horizontal = ("modifier_groups",)
