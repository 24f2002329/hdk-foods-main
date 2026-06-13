import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';
import '../models/customer_address.dart';

class AddressService {
  static final String baseUrl = "${ApiConfig.baseUrl}/addresses";

  Future<List<CustomerAddress>> getAddresses() async {
    final response = await http.get(
      Uri.parse('$baseUrl/'),
      headers: await _headers(),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((item) => CustomerAddress.fromJson(item)).toList();
    }

    throw Exception('Failed to load addresses');
  }

  Future<CustomerAddress> createAddress(CustomerAddress address) async {
    final response = await http.post(
      Uri.parse('$baseUrl/'),
      headers: await _headers(),
      body: jsonEncode(address.toJson()),
    );

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

    final response = await http.put(
      Uri.parse('$baseUrl/$id/'),
      headers: await _headers(),
      body: jsonEncode(address.toJson()),
    );

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

    final response = await http.delete(
      Uri.parse('$baseUrl/$id/'),
      headers: await _headers(),
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete address');
    }
  }

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getAccessToken();

    if (token == null) {
      throw Exception('Please login again');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
