from django.db import models
from django.contrib.auth.models import (
    AbstractBaseUser,
    PermissionsMixin,
    BaseUserManager,
)


class UserManager(BaseUserManager):

    def create_user(self, phone_number, password=None, **extra_fields):
        if not phone_number:
            raise ValueError("Phone number is required")

        user = self.model(phone_number=phone_number, **extra_fields)

        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()

        user.save(using=self._db)
        return user

    def create_superuser(self, phone_number, password=None, **extra_fields):

        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", "admin")

        return self.create_user(phone_number, password=password, **extra_fields)


class User(AbstractBaseUser, PermissionsMixin):

    ROLE_CHOICES = [
        ("customer", "Customer"),
        ("delivery", "Delivery"),
        ("admin", "Admin"),
    ]

    phone_number = models.CharField(max_length=15, unique=True)

    name = models.CharField(max_length=255, blank=True)

    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default="customer")

    is_active = models.BooleanField(default=True)

    is_staff = models.BooleanField(default=False)

    is_phone_verified = models.BooleanField(default=False)

    is_default_delivery = models.BooleanField(default=False)

    fcm_token = models.CharField(max_length=255, blank=True, default="")

    loyalty_coins = models.IntegerField(default=0)

    created_at = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = "phone_number"

    REQUIRED_FIELDS = []

    def __str__(self):
        return self.phone_number


class Address(models.Model):
    LABEL_CHOICES = [
        ("Home", "Home"),
        ("Work", "Work"),
        ("Other", "Other"),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="addresses")

    label = models.CharField(max_length=50, choices=LABEL_CHOICES)

    house = models.CharField(max_length=255, blank=True)

    street = models.CharField(max_length=255, blank=True)

    landmark = models.CharField(max_length=255, blank=True)

    city = models.CharField(max_length=100)

    pincode = models.CharField(max_length=10)

    latitude = models.DecimalField(max_digits=9, decimal_places=6, default=25.861129)

    longitude = models.DecimalField(max_digits=9, decimal_places=6, default=73.749306)

    is_default = models.BooleanField(default=False)

    def __str__(self):
        return self.label
