from rest_framework.permissions import BasePermission


class IsAdmin(BasePermission):

    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == "admin"


class IsDelivery(BasePermission):

    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == "delivery"


class IsCustomer(BasePermission):

    def has_permission(self, request, view):
        return request.user.is_authenticated and request.user.role == "customer"
