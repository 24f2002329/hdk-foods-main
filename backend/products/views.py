from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView
from authentication.permissions import IsAdmin

from .models import Category, Product
from .serializers import (
    CategorySerializer,
    ProductSerializer,
    ProductWriteSerializer,
)


class CategoryListView(generics.ListAPIView):
    queryset = Category.objects.all()
    serializer_class = CategorySerializer


class ProductListView(generics.ListAPIView):
    """Public product list — only available items for customers.

    Staff/admin can pass ?all=1 to get all products (incl. unavailable).
    """
    serializer_class = ProductSerializer

    def get_queryset(self):
        if self.request.query_params.get('all') == '1':
            return Product.objects.all().order_by('category', 'name')
        return Product.objects.filter(is_available=True).order_by('category', 'name')


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