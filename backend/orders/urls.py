from django.urls import path

from .views.customer import (
    ActiveCouponListView,
    CreateOrderView,
    MyOrdersView,
    OrderDetailView,
    QueuePositionView,
    RequestCancellationView,
    ReportNotReceivedView,
    AcknowledgeChangesView,
    ValidateCouponView,
)
from .views.admin import (
    AdminCreateOrderView,
    OrderListView,
    ConfirmOrderView,
    RejectOrderView,
    UpdateOrderStatusView,
    AssignDeliveryView,
    EditOrderItemsView,
    ApplyDiscountView,
    AdminHandleCancellationView,
    AdminCancelOrderView,
    AdminOverrideStatusView,
    PrepConfigView,
    CouponListCreateView,
    CouponDetailView,
    CouponToggleView,
    PendingOrdersView,
)
from .views.delivery import (
    DeliveryOrdersView,
    UpdateDeliveryLocationView,
    GetDeliveryLocationView,
)
from .views.payment import (
    SelectPaymentView,
    VerifyPaymentView,
    DriverInitiatePaymentView,
    DriverVerifyPaymentView,
    AdminPaymentMethodView,
    CashfreeWebhookView,
)
from .views.websocket import (
    OrderMessageListCreateView,
)
from .views.analytics import (
    AdminDashboardView,
    DailyAnalyticsView,
    PredictPrepTimeView,
)
from .views.review import (
    OrderReviewView,
    AdminReviewsListView,
    AdminProductReviewsListView,
)

from accounts.views import AdminCustomerInfoView

urlpatterns = [
    path("coupons/active/", ActiveCouponListView.as_view()),
    path("", OrderListView.as_view()),
    path("create/", CreateOrderView.as_view()),
    path("admin/create/", AdminCreateOrderView.as_view()),
    path("admin/customer-info/", AdminCustomerInfoView.as_view()),
    path("my-orders/", MyOrdersView.as_view()),
    path("<int:pk>/", OrderDetailView.as_view()),
    path("<int:pk>/confirm/", ConfirmOrderView.as_view()),
    path("<int:pk>/reject/", RejectOrderView.as_view()),
    path("<int:pk>/status/", UpdateOrderStatusView.as_view()),
    path("<int:pk>/select-payment/", SelectPaymentView.as_view()),
    path("<int:pk>/verify-payment/", VerifyPaymentView.as_view()),
    path("<int:pk>/driver-payment/", DriverInitiatePaymentView.as_view()),
    path("<int:pk>/driver-verify/", DriverVerifyPaymentView.as_view()),
    path("<int:pk>/assign-delivery/", AssignDeliveryView.as_view()),
    path("<int:pk>/edit-items/", EditOrderItemsView.as_view()),
    path("<int:pk>/apply-discount/", ApplyDiscountView.as_view()),
    path("<int:pk>/acknowledge-changes/", AcknowledgeChangesView.as_view()),
    path("<int:pk>/review/", OrderReviewView.as_view()),
    path("<int:pk>/queue-position/", QueuePositionView.as_view()),
    path("<int:pk>/delivery-location/", UpdateDeliveryLocationView.as_view()),
    path("<int:pk>/delivery-location/get/", GetDeliveryLocationView.as_view()),
    path("<int:pk>/request-cancellation/", RequestCancellationView.as_view()),
    path("<int:pk>/admin-handle-cancellation/", AdminHandleCancellationView.as_view()),
    path("<int:pk>/admin-cancel/", AdminCancelOrderView.as_view()),
    path("<int:pk>/report-not-received/", ReportNotReceivedView.as_view()),
    path("<int:pk>/override-status/", AdminOverrideStatusView.as_view()),
    path("<int:pk>/admin-payment-method/", AdminPaymentMethodView.as_view()),
    path("<int:order_id>/messages/", OrderMessageListCreateView.as_view()),
    path("delivery/", DeliveryOrdersView.as_view()),
    path("pending/", PendingOrdersView.as_view()),
    path("admin/dashboard/", AdminDashboardView.as_view()),
    path("admin/reviews/", AdminReviewsListView.as_view()),
    path("admin/product-reviews/", AdminProductReviewsListView.as_view()),
    path("admin/analytics/", DailyAnalyticsView.as_view()),
    path("coupons/", CouponListCreateView.as_view()),
    path("coupons/<int:pk>/", CouponDetailView.as_view()),
    path("coupons/<int:pk>/toggle/", CouponToggleView.as_view()),
    path("coupons/validate/", ValidateCouponView.as_view()),
    path("webhook/cashfree/", CashfreeWebhookView.as_view()),
    path("predict-prep-time/", PredictPrepTimeView.as_view()),
    path("admin/prep-config/", PrepConfigView.as_view()),
]
