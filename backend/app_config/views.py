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


from rest_framework.parsers import MultiPartParser, FormParser
import os
from django.conf import settings

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


class BannerImageUploadView(APIView):
    """Admin uploads a banner image from the device camera/gallery.

    Accepts multipart/form-data with an 'image' file field.
    Saves the file under MEDIA_ROOT/banners/ and updates banner.image_url
    with the public MEDIA_URL path.
    """

    permission_classes = [IsAdmin]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, pk):
        try:
            banner = Banner.objects.get(pk=pk)
        except Banner.DoesNotExist:
            return Response({"detail": "Not found."}, status=status.HTTP_404_NOT_FOUND)

        image_file = request.FILES.get("image")
        if not image_file:
            return Response({"detail": "No image file provided."}, status=status.HTTP_400_BAD_REQUEST)

        # Validate content type
        if not image_file.content_type.startswith("image/"):
            return Response({"detail": "File must be an image."}, status=status.HTTP_400_BAD_REQUEST)

        upload_dir = os.path.join(settings.MEDIA_ROOT, "banners")
        os.makedirs(upload_dir, exist_ok=True)

        ext = os.path.splitext(image_file.name)[1].lower() or ".jpg"
        filename = f"banner_{pk}{ext}"
        filepath = os.path.join(upload_dir, filename)

        with open(filepath, "wb") as f:
            for chunk in image_file.chunks():
                f.write(chunk)

        banner.image_url = f"{settings.MEDIA_URL}banners/{filename}"
        banner.save(update_fields=["image_url"])

        return Response(BannerSerializer(banner).data)

