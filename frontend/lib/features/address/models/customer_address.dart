class CustomerAddress {
  final int? id;
  final String label;
  final String house;
  final String street;
  final String landmark;
  final String city;
  final String pincode;
  final double latitude;
  final double longitude;
  final bool isDefault;

  const CustomerAddress({
    this.id,
    required this.label,
    required this.house,
    required this.street,
    required this.landmark,
    required this.city,
    required this.pincode,
    required this.latitude,
    required this.longitude,
    required this.isDefault,
  });

  factory CustomerAddress.fromJson(Map<String, dynamic> json) {
    return CustomerAddress(
      id: json['id'],
      label: json['label'] ?? 'Home',
      house: json['house'] ?? '',
      street: json['street'] ?? '',
      landmark: json['landmark'] ?? '',
      city: json['city'] ?? '',
      pincode: json['pincode'] ?? '',
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      isDefault: json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'house': house,
      'street': street,
      'landmark': landmark,
      'city': city,
      'pincode': pincode,
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
      'is_default': isDefault,
    };
  }

  CustomerAddress copyWith({
    int? id,
    String? label,
    String? house,
    String? street,
    String? landmark,
    String? city,
    String? pincode,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) {
    return CustomerAddress(
      id: id ?? this.id,
      label: label ?? this.label,
      house: house ?? this.house,
      street: street ?? this.street,
      landmark: landmark ?? this.landmark,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  String get lineOne {
    final parts = [house, street].where((part) => part.trim().isNotEmpty);
    return parts.join(', ');
  }

  String get lineTwo {
    final parts = [
      if (landmark.trim().isNotEmpty) landmark,
      city,
      pincode,
    ].where((part) => part.trim().isNotEmpty);

    return parts.join(', ');
  }
}
