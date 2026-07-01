import 'dart:convert';

import 'package:hdk_core/hdk_core.dart';

class DeliveryLocation {
  final double latitude;
  final double longitude;
  final DateTime? updatedAt;

  DeliveryLocation({
    required this.latitude,
    required this.longitude,
    this.updatedAt,
  });
}

class DeliveryLocationService {
  final ApiClient _apiClient = ApiClient();

  Future<DeliveryLocation?> getDeliveryLocation(int orderId) async {
    final response = await _apiClient.get(
      'orders/$orderId/delivery-location/get/',
    );

    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['available'] != true) return null;

    return DeliveryLocation(
      latitude: double.parse('${data['latitude']}'),
      longitude: double.parse('${data['longitude']}'),
      updatedAt: data['updated_at'] != null
          ? DateTime.tryParse('${data['updated_at']}')
          : null,
    );
  }
}
