import 'dart:convert';

import 'package:hdk_core/hdk_core.dart';
import '../models/customer_address.dart';

class AddressService {
  final ApiClient _apiClient = ApiClient();

  Future<List<CustomerAddress>> getAddresses() async {
    final response = await _apiClient.get('addresses/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((item) => CustomerAddress.fromJson(item)).toList();
    }

    throw Exception('Failed to load addresses');
  }

  Future<CustomerAddress> createAddress(CustomerAddress address) async {
    final response = await _apiClient.post('addresses/', address.toJson());

    if (response.statusCode == 201) {
      return CustomerAddress.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to save address');
  }

  Future<CustomerAddress> updateAddress(CustomerAddress address) async {
    final id = address.id;

    if (id == null) {
      throw Exception('Address id is required');
    }

    final response = await _apiClient.put('addresses/$id/', address.toJson());

    if (response.statusCode == 200) {
      return CustomerAddress.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to update address');
  }

  Future<void> deleteAddress(CustomerAddress address) async {
    final id = address.id;

    if (id == null) {
      throw Exception('Address id is required');
    }

    final response = await _apiClient.delete('addresses/$id/');

    if (response.statusCode != 204) {
      throw Exception('Failed to delete address');
    }
  }
}
