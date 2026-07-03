class OrderItem {
  final int? productId;
  final String productName;
  final int quantity;
  final double price;

  OrderItem({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    productId: json['product'] ?? json['product_id'],
    productName: json['product_name'] ?? 'Item',
    quantity: json['quantity'] ?? 0,
    price: double.tryParse('${json['price']}') ?? 0,
  );
}

typedef OrderItemLine = OrderItem;

class OrderAddress {
  final String label;
  final String house;
  final String street;
  final String landmark;
  final String city;
  final String pincode;
  final double? latitude;
  final double? longitude;

  OrderAddress({
    this.label = '',
    this.house = '',
    this.street = '',
    this.landmark = '',
    this.city = '',
    this.pincode = '',
    this.latitude,
    this.longitude,
  });

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      label: json['label'] ?? '',
      house: json['house'] ?? '',
      street: json['street'] ?? '',
      landmark: json['landmark'] ?? '',
      city: json['city'] ?? '',
      pincode: json['pincode'] ?? '',
      latitude: json['latitude'] != null
          ? double.tryParse('${json['latitude']}')
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse('${json['longitude']}')
          : null,
    );
  }

  String get lineOne {
    final parts = [house, street].where((p) => p.trim().isNotEmpty);
    return parts.join(', ');
  }

  String get lineTwo {
    final parts = [
      if (landmark.trim().isNotEmpty) landmark,
      city,
      if (pincode.trim().isNotEmpty) pincode,
    ].where((p) => p.trim().isNotEmpty);
    return parts.join(', ');
  }
}

class Order {
  final int id;
  final String orderNumber;
  final int? customerId;
  final int? addressId;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentSessionId;
  final double totalAmount;
  final String deliveryNotes;
  final int? estimatedPreparationTime;
  final DateTime? estimatedDeliveryTime;
  final DateTime? confirmedAt;
  final DateTime? preparingAt;
  final DateTime? outForDeliveryAt;
  final DateTime? deliveredAt;
  final DateTime? rejectedAt;
  final DateTime? cancelledAt;
  final String rejectionReason;
  final int? confirmedBy;
  final int? assignedDelivery;
  final DateTime? createdAt;
  final List<OrderItem> items;
  final bool isModifiedByStaff;
  final double discountAmount;
  final double? originalTotal;
  final String discountReason;
  final String customerName;
  final String customerPhone;
  final int coinsRedeemed;
  final int coinsEarned;
  final OrderAddress? address;

  // Cancellation properties
  final bool cancellationRequested;
  final String cancellationReason;
  final bool? cancellationApproved;
  final String refundStatus;
  final double? deliveryLatitude;
  final double? deliveryLongitude;

  // Wrong delivery correction
  final bool notReceivedReported;
  final int? predictedPreparationTime;

  Order({
    required this.id,
    required this.orderNumber,
    this.customerId,
    this.addressId,
    required this.status,
    this.paymentMethod = 'cod',
    this.paymentStatus = 'pending',
    this.paymentSessionId,
    this.totalAmount = 0,
    this.deliveryNotes = '',
    this.estimatedPreparationTime,
    this.estimatedDeliveryTime,
    this.confirmedAt,
    this.preparingAt,
    this.outForDeliveryAt,
    this.deliveredAt,
    this.rejectedAt,
    this.cancelledAt,
    this.rejectionReason = '',
    this.confirmedBy,
    this.assignedDelivery,
    this.createdAt,
    this.items = const [],
    this.isModifiedByStaff = false,
    this.discountAmount = 0,
    this.originalTotal,
    this.discountReason = '',
    this.customerName = '',
    this.customerPhone = '',
    this.coinsRedeemed = 0,
    this.coinsEarned = 0,
    this.address,
    this.cancellationRequested = false,
    this.cancellationReason = '',
    this.cancellationApproved,
    this.refundStatus = '',
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.notReceivedReported = false,
    this.predictedPreparationTime,
  });

  bool get isOnlinePaymentPending =>
      paymentMethod == 'online' && paymentStatus == 'pending';

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final addrJson = json['address_detail'] as Map<String, dynamic>?;

    return Order(
      id: json['id'],
      orderNumber: json['order_number'] ?? '',
      customerId: json['user'],
      addressId: json['address'],
      status: json['status'] ?? 'pending_confirmation',
      paymentMethod: json['payment_method'] ?? 'cod',
      paymentStatus: json['payment_status'] ?? 'pending',
      paymentSessionId: json['payment_session_id'],
      totalAmount: double.tryParse('${json['total_amount']}') ?? 0,
      deliveryNotes: json['delivery_notes'] ?? '',
      estimatedPreparationTime: json['estimated_preparation_time'],
      estimatedDeliveryTime: json['estimated_delivery_time'] != null
          ? DateTime.tryParse(json['estimated_delivery_time'])
          : null,
      confirmedAt: json['confirmed_at'] != null
          ? DateTime.tryParse(json['confirmed_at'])
          : null,
      preparingAt: json['preparing_at'] != null
          ? DateTime.tryParse(json['preparing_at'])
          : null,
      outForDeliveryAt: json['out_for_delivery_at'] != null
          ? DateTime.tryParse(json['out_for_delivery_at'])
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'])
          : null,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.tryParse(json['rejected_at'])
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.tryParse(json['cancelled_at'])
          : null,
      rejectionReason: json['rejection_reason'] ?? '',
      confirmedBy: json['confirmed_by'],
      assignedDelivery: json['assigned_delivery'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      items: rawItems
          .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      isModifiedByStaff: json['is_modified_by_staff'] ?? false,
      discountAmount: double.tryParse('${json['discount_amount']}') ?? 0,
      originalTotal: json['original_total'] != null
          ? double.tryParse('${json['original_total']}')
          : null,
      discountReason: json['discount_reason'] ?? '',
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      coinsRedeemed: json['coins_redeemed'] ?? 0,
      coinsEarned: json['coins_earned'] ?? 0,
      address: addrJson != null ? OrderAddress.fromJson(addrJson) : null,
      cancellationRequested: json['cancellation_requested'] ?? false,
      cancellationReason: json['cancellation_reason'] ?? '',
      cancellationApproved: json['cancellation_approved'],
      refundStatus: json['refund_status'] ?? '',
      deliveryLatitude: json['delivery_latitude'] != null
          ? double.tryParse('${json['delivery_latitude']}')
          : null,
      deliveryLongitude: json['delivery_longitude'] != null
          ? double.tryParse('${json['delivery_longitude']}')
          : null,
      notReceivedReported: json['not_received_reported'] ?? false,
      predictedPreparationTime: json['predicted_preparation_time'],
    );
  }
}
