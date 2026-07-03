from rest_framework import status, generics
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from authentication.permissions import IsAdmin, IsCustomer
from products.models import Product
from orders.models import Order, OrderReview, ProductReview
from orders.serializers import (
    OrderReviewSerializer,
    ProductReviewSerializer,
)
from .admin import OrderPagination


class OrderReviewView(APIView):
    """Customer submits or retrieves a review for a delivered order."""

    permission_classes = [IsCustomer]

    def get(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user)
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found."}, status=status.HTTP_404_NOT_FOUND
            )
        try:
            review = order.review
            product_reviews = ProductReview.objects.filter(order=order)
            items_data = []
            for pr in product_reviews:
                items_data.append(
                    {
                        "product_id": pr.product_id,
                        "rating": pr.rating,
                        "comment": pr.comment,
                    }
                )
            return Response(
                {
                    "rating": review.rating,
                    "comment": review.comment,
                    "submitted": True,
                    "items": items_data,
                }
            )
        except OrderReview.DoesNotExist:
            return Response({"submitted": False})

    def post(self, request, pk):
        try:
            order = Order.objects.get(pk=pk, user=request.user, status="delivered")
        except Order.DoesNotExist:
            return Response(
                {"detail": "Order not found or not yet delivered."},
                status=status.HTTP_404_NOT_FOUND,
            )
        if hasattr(order, "review"):
            return Response(
                {"detail": "Review already submitted."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        rating = request.data.get("rating")
        comment = request.data.get("comment", "")
        if not rating or not (1 <= int(rating) <= 5):
            return Response(
                {"detail": "Rating must be 1-5."}, status=status.HTTP_400_BAD_REQUEST
            )

        OrderReview.objects.create(
            order=order,
            customer=request.user,
            rating=int(rating),
            comment=comment,
        )

        items_reviews = request.data.get("items", [])
        for item_data in items_reviews:
            p_id = item_data.get("product_id")
            p_rating = item_data.get("rating")
            p_comment = item_data.get("comment", "")
            if p_id and p_rating:
                from products.models import Product

                try:
                    product = Product.objects.get(pk=p_id)
                    ProductReview.objects.create(
                        product=product,
                        customer=request.user,
                        order=order,
                        rating=int(p_rating),
                        comment=p_comment,
                    )
                except Product.DoesNotExist:
                    pass

        # Update product ratings based on all ProductReview instances for that product
        from products.models import Product
        from django.db.models import Avg

        for item in order.items.all():
            avg = ProductReview.objects.filter(product=item.product).aggregate(
                avg=Avg("rating")
            )["avg"]
            if avg is not None:
                Product.objects.filter(pk=item.product_id).update(rating=round(avg, 1))
            else:
                avg_overall = (
                    OrderReview.objects.filter(
                        order__items__product=item.product
                    ).aggregate(avg=Avg("rating"))["avg"]
                    or 0
                )
                Product.objects.filter(pk=item.product_id).update(
                    rating=round(avg_overall, 1)
                )

        return Response(
            {"detail": "Review submitted. Thank you!"}, status=status.HTTP_201_CREATED
        )


class AdminReviewsListView(generics.ListAPIView):
    """Admin: list all reviews submitted by customers (paginated)."""

    permission_classes = [IsAdmin]
    pagination_class = OrderPagination

    def get(self, request):
        reviews = OrderReview.objects.all().order_by("-created_at")
        page = self.paginate_queryset(reviews)
        if page is not None:
            serializer = OrderReviewSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = OrderReviewSerializer(reviews, many=True)
        return Response(serializer.data)


class AdminProductReviewsListView(generics.ListAPIView):
    """Admin: list all product/dish reviews submitted by customers (paginated)."""

    permission_classes = [IsAdmin]
    pagination_class = OrderPagination

    def get(self, request):
        reviews = ProductReview.objects.all().order_by("-created_at")
        page = self.paginate_queryset(reviews)
        if page is not None:
            serializer = ProductReviewSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = ProductReviewSerializer(reviews, many=True)
        return Response(serializer.data)
