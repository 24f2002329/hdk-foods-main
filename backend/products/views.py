import os
from rest_framework import generics, status
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework.views import APIView
from authentication.permissions import IsAdmin
from django.conf import settings

from .models import Category, Product
from .serializers import (
    CategorySerializer,
    ProductSerializer,
    ProductWriteSerializer,
)


class CategoryListView(APIView):
    """Public GET of all categories. Admin POST to create a new one."""

    def get_permissions(self):
        if self.request.method == "GET":
            return []
        return [IsAdmin()]

    def get(self, request):
        categories = Category.objects.all()
        return Response(CategorySerializer(categories, many=True).data)

    def post(self, request):
        serializer = CategorySerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class CategoryDetailView(APIView):
    """Admin PATCH / DELETE for a single category."""

    permission_classes = [IsAdmin]

    def _get(self, pk):
        try:
            return Category.objects.get(pk=pk)
        except Category.DoesNotExist:
            return None

    def patch(self, request, pk):
        category = self._get(pk)
        if not category:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = CategorySerializer(category, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        category = self._get(pk)
        if not category:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        category.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ProductListView(generics.ListAPIView):
    """Public product list — only available items for customers.

    Staff/admin can pass ?all=1 to get all products (incl. unavailable).
    """
    serializer_class = ProductSerializer

    def get_queryset(self):
        if self.request.query_params.get('all') == '1':
            return Product.objects.all().order_by('category', 'name')
        # Customers see available, non-add-on products in the menu.
        return Product.objects.filter(
            is_available=True, is_addon=False
        ).order_by('category', 'name')


class ProductToggleAvailabilityView(APIView):
    """Admin toggles a product's is_available flag."""

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            product = Product.objects.get(pk=pk)
        except Product.DoesNotExist:
            return Response(
                {"detail": "Product not found."},
                status=status.HTTP_404_NOT_FOUND
            )

        product.is_available = not product.is_available
        product.save(update_fields=["is_available"])

        return Response(ProductSerializer(product).data)


class FeaturedProductsView(generics.ListAPIView):
    """Public list of featured + available products, ordered by rating descending."""
    serializer_class = ProductSerializer

    def get_queryset(self):
        return Product.objects.filter(
            is_featured=True, is_available=True, is_addon=False
        ).order_by("-rating", "name")


class AddOnListView(generics.ListAPIView):
    """Public list of available add-on items (e.g. Coke, Juice) for the cart."""
    serializer_class = ProductSerializer

    def get_queryset(self):
        return Product.objects.filter(
            is_addon=True, is_available=True
        ).order_by("name")


class ProductCreateView(APIView):
    """Admin creates a new product."""

    permission_classes = [IsAdmin]

    def post(self, request):
        serializer = ProductWriteSerializer(data=request.data)
        if serializer.is_valid():
            product = serializer.save()
            return Response(
                ProductSerializer(product).data,
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ProductUpdateView(APIView):
    """Admin updates an existing product."""

    permission_classes = [IsAdmin]

    def patch(self, request, pk):
        try:
            product = Product.objects.get(pk=pk)
        except Product.DoesNotExist:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

        serializer = ProductWriteSerializer(product, data=request.data, partial=True)
        if serializer.is_valid():
            product = serializer.save()
            return Response(ProductSerializer(product).data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ProductDeleteView(APIView):
    """Admin deletes a product."""

    permission_classes = [IsAdmin]

    def delete(self, request, pk):
        try:
            product = Product.objects.get(pk=pk)
        except Product.DoesNotExist:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

        product.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class ProductImageUploadView(APIView):
    """Admin uploads a product image from the device camera/gallery.

    Accepts multipart/form-data with an 'image' file field.
    Saves the file under MEDIA_ROOT/products/ and updates product.image
    with the public MEDIA_URL path.
    """

    permission_classes = [IsAdmin]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, pk):
        try:
            product = Product.objects.get(pk=pk)
        except Product.DoesNotExist:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

        image_file = request.FILES.get("image")
        if not image_file:
            return Response({"detail": "No image file provided."}, status=status.HTTP_400_BAD_REQUEST)

        # Validate content type
        if not image_file.content_type.startswith("image/"):
            return Response({"detail": "File must be an image."}, status=status.HTTP_400_BAD_REQUEST)

        upload_dir = os.path.join(settings.MEDIA_ROOT, "products")
        os.makedirs(upload_dir, exist_ok=True)

        ext = os.path.splitext(image_file.name)[1].lower() or ".jpg"
        filename = f"product_{pk}{ext}"
        filepath = os.path.join(upload_dir, filename)

        with open(filepath, "wb") as f:
            for chunk in image_file.chunks():
                f.write(chunk)

        product.image = f"{settings.MEDIA_URL}products/{filename}"
        product.save(update_fields=["image"])

        return Response(ProductSerializer(product).data)