import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';
import '../models/delivery_staff.dart';

class DeliveryStaffService {
  static final String _base = ApiConfig.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception('Not logged in');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<DeliveryStaff>> getDeliveryStaff() async {
    final response = await http.get(
      Uri.parse('$_base/delivery-staff/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => DeliveryStaff.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load delivery staff');
  }

  Future<void> setDefaultDelivery(int userId) async {
    final response = await http.patch(
      Uri.parse('$_base/delivery-staff/$userId/set-default/'),
      headers: await _headers(),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to set default: ${response.body}');
    }
  }

  Future<DeliveryStaff> createDeliveryStaff({
    required String phone,
    required String name,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$_base/delivery-staff/create/'),
      headers: await _headers(),
      body: jsonEncode({'phone_number': phone, 'name': name, 'password': password}),
    );
    if (response.statusCode == 201) {
      return DeliveryStaff.fromJson(jsonDecode(response.body));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final msg = body.values.first;
    throw Exception(msg is List ? msg.first : '$msg');
  }
}
