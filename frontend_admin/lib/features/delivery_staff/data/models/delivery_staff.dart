class DeliveryStaff {
  final int id;
  final String phoneNumber;
  final String name;
  final bool isDefaultDelivery;

  DeliveryStaff({
    required this.id,
    required this.phoneNumber,
    required this.name,
    required this.isDefaultDelivery,
  });

  factory DeliveryStaff.fromJson(Map<String, dynamic> json) => DeliveryStaff(
    id: json['id'],
    phoneNumber: json['phone_number'] ?? '',
    name: json['name'] ?? '',
    isDefaultDelivery: json['is_default_delivery'] ?? false,
  );

  String get displayName => name.isNotEmpty ? name : phoneNumber;
}
