from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.views import APIView

from authentication.permissions import IsAdmin
from .models import Banner, SiteConfig
from .serializers import BannerSerializer, SiteConfigSerializer


class SiteConfigView(APIView):
    """Public GET + admin PATCH for site-wide configuration."""

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAdmin()]

    def get(self, request):
        config = SiteConfig.get()
        return Response(SiteConfigSerializer(config).data)

    def patch(self, request):
        config = SiteConfig.get()
        serializer = SiteConfigSerializer(config, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class BannerListView(APIView):
    """Public GET of active banners; admin can POST to create."""

    def get_permissions(self):
        if self.request.method == "GET":
            return [AllowAny()]
        return [IsAdmin()]

    def get(self, request):
        banners = Banner.objects.filter(is_active=True).order_by("order")
        return Response(BannerSerializer(banners, many=True).data)

    def post(self, request):
        serializer = BannerSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class BannerDetailView(APIView):
    """Admin PATCH / DELETE for a single banner."""

    permission_classes = [IsAdmin]

    def _get(self, pk):
        try:
            return Banner.objects.get(pk=pk)
        except Banner.DoesNotExist:
            return None

    def patch(self, request, pk):
        banner = self._get(pk)
        if not banner:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        serializer = BannerSerializer(banner, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        banner = self._get(pk)
        if not banner:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)
        banner.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class BroadcastNotificationView(APIView):
    """Admin sends a push notification to all customers with an FCM token."""

    permission_classes = [IsAdmin]

    def post(self, request):
        title = request.data.get("title", "")
        body = request.data.get("body", "")
        if not title or not body:
            return Response(
                {"detail": "title and body are required."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from authentication.firebase import send_push_to_all
        count = send_push_to_all(title=title, body=body)
        return Response({"sent": count})
