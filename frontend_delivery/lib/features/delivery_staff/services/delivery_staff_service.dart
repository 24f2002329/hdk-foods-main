import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:hdk_core/hdk_core.dart';
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
}
