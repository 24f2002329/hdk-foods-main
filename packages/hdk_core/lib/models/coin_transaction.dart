class CoinTransaction {
  final String id;
  final int orderId;
  final String orderNumber;
  final int amount;
  final String type; // 'earned', 'redeemed', 'refunded'
  final String description;
  final DateTime createdAt;

  CoinTransaction({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.amount,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  factory CoinTransaction.fromJson(Map<String, dynamic> json) {
    return CoinTransaction(
      id: json['id'],
      orderId: json['order_id'],
      orderNumber: json['order_number'] ?? '',
      amount: json['amount'],
      type: json['type'] ?? 'earned',
      description: json['description'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}
