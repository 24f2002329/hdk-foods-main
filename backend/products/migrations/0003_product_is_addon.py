from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("products", "0002_product_rating"),
    ]

    operations = [
        migrations.AddField(
            model_name="product",
            name="is_addon",
            field=models.BooleanField(default=False),
        ),
    ]
