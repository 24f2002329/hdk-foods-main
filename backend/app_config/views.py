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

        # Create global Notification database record
        from .models import Notification
        try:
            Notification.objects.create(title=title, body=body, user=None)
        except Exception:
            pass

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
        content_type = image_file.content_type or ""
        ext = os.path.splitext(image_file.name)[1].lower()
        is_image_ext = ext in [".jpg", ".jpeg", ".png", ".gif", ".webp", ".bmp"]
        if not (content_type.startswith("image/") or is_image_ext):
            return Response({"detail": "File must be an image."}, status=status.HTTP_400_BAD_REQUEST)

        ext = os.path.splitext(image_file.name)[1].lower() or ".jpg"
        filename = f"banner_{pk}{ext}"

        import firebase_admin
        if firebase_admin._apps:
            from authentication.firebase import upload_file_to_firebase
            import logging
            logger = logging.getLogger(__name__)
            try:
                banner.image_url = upload_file_to_firebase(image_file, f"banners/{filename}")
                banner.save(update_fields=["image_url"])
                return Response(BannerSerializer(banner).data)
            except Exception as e:
                logger.error("Firebase upload failed, falling back to local storage: %s", e)

        upload_dir = os.path.join(settings.MEDIA_ROOT, "banners")
        os.makedirs(upload_dir, exist_ok=True)
        filepath = os.path.join(upload_dir, filename)

        with open(filepath, "wb") as f:
            for chunk in image_file.chunks():
                f.write(chunk)

        banner.image_url = f"{settings.MEDIA_URL}banners/{filename}"
        banner.save(update_fields=["image_url"])

        return Response(BannerSerializer(banner).data)


class NotificationListView(APIView):
    """List customer notifications (user-specific and global announcements)."""
    from rest_framework.permissions import IsAuthenticated
    permission_classes = [IsAuthenticated]

    def get(self, request):
        from django.db.models import Q
        from .models import Notification
        from .serializers import NotificationSerializer
        notifications = Notification.objects.filter(
            Q(user=request.user) | Q(user__isnull=True)
        ).order_by("-created_at")
        serializer = NotificationSerializer(notifications, many=True)
        unread_count = notifications.filter(is_read=False).count()
        return Response({
            "notifications": serializer.data,
            "unread_count": unread_count
        })

    def post(self, request):
        """Mark all notifications as read."""
        from django.db.models import Q
        from .models import Notification
        Notification.objects.filter(
            Q(user=request.user) | Q(user__isnull=True)
        ).update(is_read=True)
        return Response({"detail": "All notifications marked as read."})


class MarkNotificationReadView(APIView):
    """Mark a specific notification as read."""
    from rest_framework.permissions import IsAuthenticated
    permission_classes = [IsAuthenticated]

    def post(self, request, pk):
        from django.db.models import Q
        from .models import Notification
        try:
            notification = Notification.objects.get(
                Q(pk=pk) & (Q(user=request.user) | Q(user__isnull=True))
            )
            notification.is_read = True
            notification.save(update_fields=["is_read"])
            return Response({"detail": "Notification marked as read."})
        except Notification.DoesNotExist:
            return Response({"detail": "Notification not found."}, status=status.HTTP_404_NOT_FOUND)

