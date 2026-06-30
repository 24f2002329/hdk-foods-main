class OrderReviewModel {
  final int id;
  final int orderId;
  final String orderNumber;
  final int customerId;
  final String customerName;
  final String customerPhone;
  final int rating;
  final String comment;
  final DateTime createdAt;

  OrderReviewModel({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory OrderReviewModel.fromJson(Map<String, dynamic> json) {
    return OrderReviewModel(
      id: json['id'] ?? 0,
      orderId: json['order'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      customerId: json['customer'] ?? 0,
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class ProductReviewModel {
  final int id;
  final int productId;
  final String productName;
  final int customerId;
  final String customerName;
  final String customerPhone;
  final int orderId;
  final String orderNumber;
  final int rating;
  final String comment;
  final DateTime createdAt;

  ProductReviewModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.orderId,
    required this.orderNumber,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory ProductReviewModel.fromJson(Map<String, dynamic> json) {
    return ProductReviewModel(
      id: json['id'] ?? 0,
      productId: json['product'] ?? 0,
      productName: json['product_name'] ?? '',
      customerId: json['customer'] ?? 0,
      customerName: json['customer_name'] ?? '',
      customerPhone: json['customer_phone'] ?? '',
      orderId: json['order'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
