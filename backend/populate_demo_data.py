import os
import django
import sys
from datetime import datetime, timedelta

# Set up Django environment
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
django.setup()

from products.models import Category, Product, ModifierGroup, ModifierOption, ProductModifierOptionOverride
from app_config.models import SiteConfig, Banner
from orders.models import Coupon

def populate():
    print("Starting database population...")

    # 1. Ensure SiteConfig is open and configured
    print("Configuring SiteConfig...")
    config = SiteConfig.get()
    config.is_store_open = True
    config.announcement = "🎉 100% Vegetarian Premium Kitchen — Freshness Guaranteed!"
    config.store_closed_msg = "We're currently closed, preparing fresh dough for tomorrow!"
    config.save()

    # 2. Clear existing categories and products to start clean
    print("Clearing old products, categories, banners, and coupons...")
    Product.objects.all().delete()
    Category.objects.all().delete()
    Banner.objects.all().delete()
    Coupon.objects.all().delete()

    # 3. Create Categories
    categories_data = [
        {"name": "Pizza", "image": "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=200&auto=format&fit=crop&q=80"},
        {"name": "Momos", "image": "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=200&auto=format&fit=crop&q=80"},
        {"name": "Burgers", "image": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=200&auto=format&fit=crop&q=80"},
        {"name": "Boba Tea", "image": "https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=200&auto=format&fit=crop&q=80"},
        {"name": "Sides & Fries", "image": "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=200&auto=format&fit=crop&q=80"},
        {"name": "Desserts", "image": "https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=200&auto=format&fit=crop&q=80"},
        {"name": "Drinks", "image": "https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=200&auto=format&fit=crop&q=80"},
        {"name": "Combos", "image": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=200&auto=format&fit=crop&q=80"}
    ]

    categories = {}
    for cat in categories_data:
        c = Category.objects.create(name=cat["name"], image=cat["image"])
        categories[cat["name"]] = c
        print(f"Created category: {c.name}")

    # 4. Create Banners
    banners_data = [
        {
            "title": "Premium Tandoori Paneer Pizza",
            "subtitle": "Spicy paneer tikka, green capsicum & loaded mozzarella.",
            "image_url": "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&auto=format&fit=crop&q=80",
            "link_action": "menu",
            "order": 1
        },
        {
            "title": "Steamed Veg Momo Feast",
            "subtitle": "Traditional Himalayan momos served with spicy red chili chutney.",
            "image_url": "https://images.unsplash.com/photo-1625220194771-7ebedd0b70b9?w=600&auto=format&fit=crop&q=80",
            "link_action": "menu",
            "order": 2
        },
        {
            "title": "Brown Sugar Bubble Tea",
            "subtitle": "Slow-brewed black tea, sweet caramel syrup, and tapioca pearls.",
            "image_url": "https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=600&auto=format&fit=crop&q=80",
            "link_action": "menu",
            "order": 3
        }
    ]

    for b in banners_data:
        Banner.objects.create(
            title=b["title"],
            subtitle=b["subtitle"],
            image_url=b["image_url"],
            link_action=b["link_action"],
            order=b["order"],
            is_active=True
        )
        print(f"Created banner: {b['title']}")

    # 5. Create Coupons
    coupons_data = [
        {
            "code": "HDK50",
            "discount_type": "percentage",
            "discount_value": 15.00,
            "min_order_amount": 250.00,
            "max_discount_amount": 75.00,
            "is_active": True
        },
        {
            "code": "VEGCOMBO",
            "discount_type": "flat",
            "discount_value": 50.00,
            "min_order_amount": 350.00,
            "max_discount_amount": 50.00,
            "is_active": True
        },
        {
            "code": "BOBALOVE",
            "discount_type": "percentage",
            "discount_value": 20.00,
            "min_order_amount": 199.00,
            "max_discount_amount": 40.00,
            "is_active": True
        }
    ]

    for cp in coupons_data:
        Coupon.objects.create(
            code=cp["code"],
            discount_type=cp["discount_type"],
            discount_value=cp["discount_value"],
            min_order_amount=cp["min_order_amount"],
            max_discount_amount=cp["max_discount_amount"],
            is_active=cp["is_active"],
            valid_from=datetime.now(),
            valid_until=datetime.now() + timedelta(days=30)
        )
        print(f"Created coupon: {cp['code']}")

    # 6. Create Products (100% Vegetarian)
    products_data = [
        # --- Pizza Category ---
        {
            "category": "Pizza",
            "name": "Garden Delight Pizza",
            "description": "Loaded with onions, crisp capsicum, juicy tomatoes, golden sweet corn, and mozzarella cheese.",
            "price": 289.00,
            "strike_price": 349.00,
            "image": "https://images.unsplash.com/photo-1513104890138-7c749659a591?w=600&auto=format&fit=crop&q=80",
            "is_featured": True,
            "rating": 4.5,
            "promo_tag": "Bestseller"
        },
        {
            "category": "Pizza",
            "name": "Tandoori Paneer Tikka Pizza",
            "description": "Premium tandoori paneer cubes, red onions, capsicum, and hot garlic dip drizzle.",
            "price": 329.00,
            "strike_price": 399.00,
            "image": "https://images.unsplash.com/photo-1565299624946-b28f40a0ae38?w=600&auto=format&fit=crop&q=80",
            "is_featured": True,
            "rating": 4.8,
            "promo_tag": "Chef's Special"
        },
        {
            "category": "Pizza",
            "name": "Triple Cheese Margherita",
            "description": "Classic sourdough base, rich tomato sauce, loaded with mozzarella, cheddar, and Monterey Jack cheese.",
            "price": 249.00,
            "strike_price": 299.00,
            "image": "https://images.unsplash.com/photo-1574071318508-1cdbab80d002?w=600&auto=format&fit=crop&q=80",
            "is_featured": False,
            "rating": 4.3,
            "promo_tag": "20% OFF"
        },

        # --- Momos Category ---
        {
            "category": "Momos",
            "name": "Steamed Cheese & Corn Momos",
            "description": "Stuffed with sweet corn, spring onions, and gooey mozzarella cheese. Served with spicy momo chutney.",
            "price": 149.00,
            "strike_price": 179.00,
            "image": "https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600&auto=format&fit=crop&q=80",
            "is_featured": True,
            "rating": 4.4,
            "promo_tag": "Hot Seller"
        },
        {
            "category": "Momos",
            "name": "Crispy Fried Veg Momos",
            "description": "Golden fried dumplings filled with finely chopped cabbage, carrots, beans, and seasoned spices.",
            "price": 129.00,
            "strike_price": 159.00,
            "image": "https://images.unsplash.com/photo-1625220194771-7ebedd0b70b9?w=600&auto=format&fit=crop&q=80",
            "is_featured": False,
            "rating": 4.2,
            "promo_tag": "Trending"
        },

        # --- Burgers Category ---
        {
            "category": "Burgers",
            "name": "Premium Crunchy Paneer Burger",
            "description": "Crispy paneer patty, layered with spicy mayo, sliced tomatoes, onions, and crunchy lettuce.",
            "price": 159.00,
            "strike_price": 199.00,
            "image": "https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=600&auto=format&fit=crop&q=80",
            "is_featured": True,
            "rating": 4.6,
            "promo_tag": "Buy 1 Get 1"
        },
        {
            "category": "Burgers",
            "name": "Classic Aloo Tikki Cheese Burger",
            "description": "Spiced mashed potato patty, single cheese slice, house sauce, toasted sesame buns.",
            "price": 99.00,
            "strike_price": 129.00,
            "image": "https://images.unsplash.com/photo-1586190848861-99aa4a171e90?w=600&auto=format&fit=crop&q=80",
            "is_featured": False,
            "rating": 4.1,
            "promo_tag": ""
        },

        # --- Boba Tea Category ---
        {
            "category": "Boba Tea",
            "name": "Classic Brown Sugar Boba Milk Tea",
            "description": "Premium black tea leaves, creamy milk, authentic brown sugar syrup, and chewy black tapioca pearls.",
            "price": 199.00,
            "strike_price": 249.00,
            "image": "https://images.unsplash.com/photo-1541658016709-82535e94bc69?w=600&auto=format&fit=crop&q=80",
            "is_featured": True,
            "rating": 4.7,
            "promo_tag": "Top Rated"
        },
        {
            "category": "Boba Tea",
            "name": "Mango Matcha Bubble Tea",
            "description": "Japanese ceremonial matcha layered with fresh mango puree and sweet tapioca pearls.",
            "price": 219.00,
            "strike_price": 269.00,
            "image": "https://images.unsplash.com/photo-1507048680185-457351659e51?w=600&auto=format&fit=crop&q=80",
            "is_featured": False,
            "rating": 4.4,
            "promo_tag": "New Flavor"
        },

        # --- Sides & Fries Category ---
        {
            "category": "Sides & Fries",
            "name": "Peri Peri Crinkle Fries",
            "description": "Crispy crinkle-cut potatoes tossed in aromatic and spicy peri-peri spice blend.",
            "price": 119.00,
            "strike_price": 149.00,
            "image": "https://images.unsplash.com/photo-1573080496219-bb080dd4f877?w=600&auto=format&fit=crop&q=80",
            "is_featured": False,
            "rating": 4.3,
            "promo_tag": ""
        },
        {
            "category": "Sides & Fries",
            "name": "Stuffed Cheese Garlic Bread",
            "description": "Freshly baked garlic loaf stuffed with sweet corn, jalapeños, and loaded with liquid cheese.",
            "price": 179.00,
            "strike_price": 219.00,
            "image": "https://images.unsplash.com/photo-1619535860434-ba1d8fa12536?w=600&auto=format&fit=crop&q=80",
            "is_featured": True,
            "rating": 4.6,
            "promo_tag": "Bestseller"
        },

        # --- Desserts Category ---
        {
            "category": "Desserts",
            "name": "Warm Fudge Choco Lava Cake",
            "description": "Decadent chocolate cake with a rich, hot molten chocolate center oozing out.",
            "price": 99.00,
            "strike_price": 129.00,
            "image": "https://images.unsplash.com/photo-1563729784474-d77dbb933a9e?w=600&auto=format&fit=crop&q=80",
            "is_featured": True,
            "rating": 4.9,
            "promo_tag": "Sinful"
        },

        # --- Drinks Category ---
        {
            "category": "Drinks",
            "name": "Blueberry Mint Mojito",
            "description": "Muddled fresh blueberries, mint leaves, fresh lime juice, sugar syrup, topped with sparkling club soda.",
            "price": 129.00,
            "strike_price": 159.00,
            "image": "https://images.unsplash.com/photo-1513558161293-cdaf765ed2fd?w=600&auto=format&fit=crop&q=80",
            "is_featured": False,
            "rating": 4.3,
            "promo_tag": "Refreshing"
        },

        # --- Combos Category ---
        {
            "category": "Combos",
            "name": "Mega Pizza & Boba Combo",
            "description": "Choose any 1 Premium Personal Pizza + 1 Classic Brown Sugar Boba Tea. Complete meal for one!",
            "price": 399.00,
            "strike_price": 598.00,
            "image": "https://images.unsplash.com/photo-1604908176997-125f25cc6f3d?w=600&auto=format&fit=crop&q=80",
            "is_featured": True,
            "rating": 4.7,
            "promo_tag": "Save ₹199"
        },
        {
            "category": "Combos",
            "name": "Mega Momos & Mojito Combo",
            "description": "1 Plate Crispy Fried Veg Momos + 1 Refreshing Blueberry Mint Mojito. Best evening snack combo!",
            "price": 229.00,
            "strike_price": 318.00,
            "image": "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop&q=80",
            "is_featured": False,
            "rating": 4.5,
            "promo_tag": "Save ₹89"
        }
    ]

    for prod in products_data:
        p = Product.objects.create(
            category=categories[prod["category"]],
            name=prod["name"],
            description=prod["description"],
            price=prod["price"],
            strike_price=prod["strike_price"],
            image=prod["image"],
            is_available=True,
            is_featured=prod["is_featured"],
            rating=prod["rating"],
            promo_tag=prod["promo_tag"]
        )
        print(f"Created veg product: {p.name} (Category: {p.category.name})")

    # Clear old modifiers
    ModifierGroup.objects.all().delete()
    ModifierOption.objects.all().delete()
    ProductModifierOptionOverride.objects.all().delete()

    print("Creating Modifier Groups and Options...")
    
    # 1. Size Group (Pizza / Drinks / Boba)
    mg_pizza_size = ModifierGroup.objects.create(
        name="Choose Size",
        selection_type="SINGLE",
        required=True,
        min_selection=1,
        max_selection=1,
        display_order=1,
        description="Select your pizza size"
    )
    opt_pizza_s = ModifierOption.objects.create(modifier_group=mg_pizza_size, name="Personal (7\")", extra_price=0.00, sort_order=1)
    opt_pizza_m = ModifierOption.objects.create(modifier_group=mg_pizza_size, name="Medium (10\")", extra_price=90.00, sort_order=2)
    opt_pizza_l = ModifierOption.objects.create(modifier_group=mg_pizza_size, name="Large (12\")", extra_price=170.00, sort_order=3)

    mg_boba_size = ModifierGroup.objects.create(
        name="Choose Size",
        selection_type="SINGLE",
        required=True,
        min_selection=1,
        max_selection=1,
        display_order=1,
        description="Select cup size"
    )
    ModifierOption.objects.create(modifier_group=mg_boba_size, name="Regular", extra_price=0.00, sort_order=1)
    ModifierOption.objects.create(modifier_group=mg_boba_size, name="Large", extra_price=40.00, sort_order=2)

    # 2. Pizza Crust Group
    mg_pizza_crust = ModifierGroup.objects.create(
        name="Choose Crust",
        selection_type="SINGLE",
        required=True,
        min_selection=1,
        max_selection=1,
        display_order=2,
        description="Select your pizza crust base"
    )
    ModifierOption.objects.create(modifier_group=mg_pizza_crust, name="Classic Hand Tossed", extra_price=0.00, sort_order=1)
    opt_crust_cb = ModifierOption.objects.create(modifier_group=mg_pizza_crust, name="Cheese Burst", extra_price=99.00, sort_order=2)
    ModifierOption.objects.create(modifier_group=mg_pizza_crust, name="Thin Crust", extra_price=20.00, sort_order=3)

    # 3. Pizza Extra Toppings Group
    mg_pizza_toppings = ModifierGroup.objects.create(
        name="Select Extra Toppings",
        selection_type="MULTIPLE",
        required=False,
        min_selection=0,
        max_selection=5,
        display_order=3,
        description="Add veggies & toppings"
    )
    ModifierOption.objects.create(modifier_group=mg_pizza_toppings, name="Extra Onion", extra_price=20.00, sort_order=1)
    ModifierOption.objects.create(modifier_group=mg_pizza_toppings, name="Golden Sweet Corn", extra_price=30.00, sort_order=2)
    ModifierOption.objects.create(modifier_group=mg_pizza_toppings, name="Black Olives", extra_price=30.00, sort_order=3)
    ModifierOption.objects.create(modifier_group=mg_pizza_toppings, name="Paneer Cubes", extra_price=45.00, sort_order=4)
    ModifierOption.objects.create(modifier_group=mg_pizza_toppings, name="Jalapeños", extra_price=30.00, sort_order=5)

    # 4. Extra Cheese Group (Pizza / Burgers)
    mg_extra_cheese = ModifierGroup.objects.create(
        name="Add Extra Cheese",
        selection_type="MULTIPLE",
        required=False,
        min_selection=0,
        max_selection=2,
        display_order=4,
        description="Loaded cheesy goodness"
    )
    ModifierOption.objects.create(modifier_group=mg_extra_cheese, name="Cheddar Cheese Slice", extra_price=25.00, sort_order=1)
    ModifierOption.objects.create(modifier_group=mg_extra_cheese, name="Mozzarella Cheese", extra_price=45.00, sort_order=2)

    # 5. Spice Level Group (Momos / Burgers / Sides)
    mg_spice_level = ModifierGroup.objects.create(
        name="Choose Spice Level",
        selection_type="SINGLE",
        required=True,
        min_selection=1,
        max_selection=1,
        display_order=1,
        description="Specify heat level"
    )
    ModifierOption.objects.create(modifier_group=mg_spice_level, name="Mild (No Spice)", extra_price=0.00, sort_order=1)
    ModifierOption.objects.create(modifier_group=mg_spice_level, name="Medium (Perfect)", extra_price=0.00, sort_order=2)
    ModifierOption.objects.create(modifier_group=mg_spice_level, name="Hot (Spicy)", extra_price=0.00, sort_order=3)
    ModifierOption.objects.create(modifier_group=mg_spice_level, name="Extra Hot (Fiery)", extra_price=0.00, sort_order=4)

    # 6. Boba Sweetness Level Group
    mg_boba_sweetness = ModifierGroup.objects.create(
        name="Sugar Level",
        selection_type="SINGLE",
        required=True,
        min_selection=1,
        max_selection=1,
        display_order=2,
        description="Select sweetness level"
    )
    ModifierOption.objects.create(modifier_group=mg_boba_sweetness, name="25% (Less Sweet)", extra_price=0.00, sort_order=1)
    ModifierOption.objects.create(modifier_group=mg_boba_sweetness, name="50% (Half Sweet)", extra_price=0.00, sort_order=2)
    ModifierOption.objects.create(modifier_group=mg_boba_sweetness, name="75% (Normal Sweet)", extra_price=0.00, sort_order=3)
    ModifierOption.objects.create(modifier_group=mg_boba_sweetness, name="100% (Extra Sweet)", extra_price=0.00, sort_order=4)

    # 7. Boba Ice Level Group
    mg_boba_ice = ModifierGroup.objects.create(
        name="Ice Level",
        selection_type="SINGLE",
        required=True,
        min_selection=1,
        max_selection=1,
        display_order=3,
        description="Select ice preference"
    )
    ModifierOption.objects.create(modifier_group=mg_boba_ice, name="No Ice", extra_price=0.00, sort_order=1)
    ModifierOption.objects.create(modifier_group=mg_boba_ice, name="Less Ice", extra_price=0.00, sort_order=2)
    ModifierOption.objects.create(modifier_group=mg_boba_ice, name="Normal Ice", extra_price=0.00, sort_order=3)
    ModifierOption.objects.create(modifier_group=mg_boba_ice, name="Extra Ice", extra_price=0.00, sort_order=4)

    # 8. Boba Add-ons/Toppings Group
    mg_boba_addons = ModifierGroup.objects.create(
        name="Add Extra Toppings",
        selection_type="MULTIPLE",
        required=False,
        min_selection=0,
        max_selection=4,
        display_order=4,
        description="Choose tapioca pearls or jellies"
    )
    ModifierOption.objects.create(modifier_group=mg_boba_addons, name="Extra Tapioca Pearls", extra_price=35.00, sort_order=1)
    ModifierOption.objects.create(modifier_group=mg_boba_addons, name="Coconut Jelly", extra_price=30.00, sort_order=2)
    ModifierOption.objects.create(modifier_group=mg_boba_addons, name="Mango Popping Boba", extra_price=40.00, sort_order=3)
    ModifierOption.objects.create(modifier_group=mg_boba_addons, name="Whipped Cream", extra_price=25.00, sort_order=4)

    # 9. Burger Add-ons Group
    mg_burger_addons = ModifierGroup.objects.create(
        name="Customize Burger",
        selection_type="MULTIPLE",
        required=False,
        min_selection=0,
        max_selection=3,
        display_order=2,
        description="Add patty or sauces"
    )
    ModifierOption.objects.create(modifier_group=mg_burger_addons, name="Extra Veg Patty", extra_price=50.00, sort_order=1)
    ModifierOption.objects.create(modifier_group=mg_burger_addons, name="Tandoori Mayo Drizzle", extra_price=15.00, sort_order=2)
    ModifierOption.objects.create(modifier_group=mg_burger_addons, name="Spicy Jalapeños", extra_price=20.00, sort_order=3)

    # 10. Fries customizations
    mg_fries_addons = ModifierGroup.objects.create(
        name="Add Dips & Seasoning",
        selection_type="MULTIPLE",
        required=False,
        min_selection=0,
        max_selection=3,
        display_order=1,
        description="Make it loaded"
    )
    ModifierOption.objects.create(modifier_group=mg_fries_addons, name="Creamy Cheese Sauce", extra_price=30.00, sort_order=1)
    ModifierOption.objects.create(modifier_group=mg_fries_addons, name="Chipotle Mayo Dip", extra_price=20.00, sort_order=2)
    ModifierOption.objects.create(modifier_group=mg_fries_addons, name="Extra Peri Peri Shaker Dust", extra_price=10.00, sort_order=3)

    print("Linking Modifier Groups to Products...")
    for p in Product.objects.all():
        if p.category.name == "Pizza":
            p.modifier_groups.add(mg_pizza_size, mg_pizza_crust, mg_pizza_toppings, mg_extra_cheese)
            if p.name == "Tandoori Paneer Tikka Pizza":
                ProductModifierOptionOverride.objects.create(
                    product=p,
                    modifier_option=opt_crust_cb,
                    extra_price=119.00
                )
        elif p.category.name == "Boba Tea":
            p.modifier_groups.add(mg_boba_size, mg_boba_sweetness, mg_boba_ice, mg_boba_addons)
        elif p.category.name == "Burgers":
            p.modifier_groups.add(mg_spice_level, mg_extra_cheese, mg_burger_addons)
        elif p.category.name == "Momos":
            p.modifier_groups.add(mg_spice_level)
        elif p.category.name == "Sides & Fries":
            if "Fries" in p.name:
                p.modifier_groups.add(mg_fries_addons)

    print("\nSUCCESS: Realistic 100% vegetarian demo data successfully populated!")


if __name__ == "__main__":
    populate()
