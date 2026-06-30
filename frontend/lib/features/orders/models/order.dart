class OrderItemLine {
  final int? productId;
  final String productName;
  final int quantity;
  final double price;

  OrderItemLine({
    this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
  });

  factory OrderItemLine.fromJson(Map<String, dynamic> json) {
    return OrderItemLine(
      productId: json['product'],
      productName: json['product_name'] ?? 'Item',
      quantity: json['quantity'] ?? 0,
      price: double.tryParse('${json['price']}') ?? 0,
    );
  }
}

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
  final String status;
  final double totalAmount;
  final String paymentMethod;
  final String paymentStatus;
  final String? paymentSessionId;
  final DateTime? createdAt;
  final List<OrderItemLine> items;

  // Staff-modification fields
  final bool isModifiedByStaff;
  final double discountAmount;
  final double? originalTotal;
  final String discountReason;
  final DateTime? estimatedDeliveryTime;

  // Delivery
  final OrderAddress? address;
  final String deliveryNotes;

  // Cancellation properties
  final bool cancellationRequested;
  final String cancellationReason;
  final bool? cancellationApproved;
  final String refundStatus;
  final int coinsRedeemed;
  final int coinsEarned;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.totalAmount = 0,
    this.paymentMethod = 'cod',
    this.paymentStatus = 'pending',
    this.paymentSessionId,
    this.createdAt,
    this.items = const [],
    this.isModifiedByStaff = false,
    this.discountAmount = 0,
    this.originalTotal,
    this.discountReason = '',
    this.estimatedDeliveryTime,
    this.address,
    this.deliveryNotes = '',
    this.cancellationRequested = false,
    this.cancellationReason = '',
    this.cancellationApproved,
    this.refundStatus = '',
    this.coinsRedeemed = 0,
    this.coinsEarned = 0,
  });

  bool get isOnlinePaymentPending =>
      paymentMethod == 'online' && paymentStatus == 'pending';

  factory Order.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final createdAtStr = json['created_at'] as String?;
    DateTime? createdAt;
    if (createdAtStr != null) {
      try {
        createdAt = DateTime.parse(createdAtStr);
      } catch (_) {
        createdAt = null;
      }
    }

    final addrJson = json['address_detail'] as Map<String, dynamic>?;

    return Order(
      id: json['id'],
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'pending_confirmation',
      totalAmount: double.tryParse('${json['total_amount']}') ?? 0,
      paymentMethod: json['payment_method'] ?? 'cod',
      paymentStatus: json['payment_status'] ?? 'pending',
      paymentSessionId: json['payment_session_id'],
      createdAt: createdAt,
      items: rawItems
          .map((e) => OrderItemLine.fromJson(e as Map<String, dynamic>))
          .toList(),
      isModifiedByStaff: json['is_modified_by_staff'] ?? false,
      discountAmount: double.tryParse('${json['discount_amount']}') ?? 0,
      originalTotal: json['original_total'] != null
          ? double.tryParse('${json['original_total']}')
          : null,
      discountReason: json['discount_reason'] ?? '',
      estimatedDeliveryTime: json['estimated_delivery_time'] != null
          ? DateTime.tryParse(json['estimated_delivery_time'])
          : null,
      address: addrJson != null ? OrderAddress.fromJson(addrJson) : null,
      deliveryNotes: json['delivery_notes'] ?? '',
      cancellationRequested: json['cancellation_requested'] ?? false,
      cancellationReason: json['cancellation_reason'] ?? '',
      cancellationApproved: json['cancellation_approved'],
      refundStatus: json['refund_status'] ?? '',
      coinsRedeemed: json['coins_redeemed'] ?? 0,
      coinsEarned: json['coins_earned'] ?? 0,
    );
  }
}
