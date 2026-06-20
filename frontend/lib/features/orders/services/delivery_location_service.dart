import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';

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
  static final String _base = "${ApiConfig.baseUrl}/orders";

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception('Not logged in');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<DeliveryLocation?> getDeliveryLocation(int orderId) async {
    final response = await http.get(
      Uri.parse('$_base/$orderId/delivery-location/get/'),
      headers: await _headers(),
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
