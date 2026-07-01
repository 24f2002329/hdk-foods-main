import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';
import '../models/delivery_staff.dart';

class DeliveryStaffService {
  final ApiClient _apiClient = ApiClient();

  Future<List<DeliveryStaff>> getDeliveryStaff() async {
    final response = await _apiClient.get('delivery-staff/');
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => DeliveryStaff.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load delivery staff');
  }
}
