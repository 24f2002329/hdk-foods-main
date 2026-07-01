import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';
import '../models/delivery_staff.dart';

class DeliveryStaffService {
  static final String _base = ApiConfig.baseUrl;

  Future<List<DeliveryStaff>> getDeliveryStaff() async {
    final response = await ApiClient().get('$_base/delivery-staff/');
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => DeliveryStaff.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load delivery staff');
  }

  Future<void> setDefaultDelivery(int userId) async {
    final response = await ApiClient().patch(
      '$_base/delivery-staff/$userId/set-default/',
      {},
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
    final response = await ApiClient().post('$_base/delivery-staff/create/', {
      'phone_number': phone,
      'name': name,
      'password': password,
    });
    if (response.statusCode == 201) {
      return DeliveryStaff.fromJson(jsonDecode(response.body));
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final msg = body.values.first;
    throw Exception(msg is List ? msg.first : '$msg');
  }
}
