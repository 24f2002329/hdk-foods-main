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
  });

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
    );
  }
}
