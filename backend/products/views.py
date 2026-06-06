# from django.shortcuts import render

# Create your views here.
from rest_framework import generics

from .models import Category, Product
from .serializers import (
    CategorySerializer,
    ProductSerializer
)


class CategoryListView(generics.ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer


class ProductListView(generics.ListAPIView):
    queryset = Product.objects.filter(
        is_available=True
    )
    serializer_class = ProductSerializer