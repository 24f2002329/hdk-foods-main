import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';
import '../../data/models/customer_address.dart';

abstract class AddressRepository {
  static AddressRepository? _instance;
  static AddressRepository get instance => _instance ??= HttpAddressRepository();
  static set instance(AddressRepository value) => _instance = value;

  Future<List<CustomerAddress>> getAddresses();
  Future<CustomerAddress> createAddress(CustomerAddress address);
  Future<CustomerAddress> updateAddress(CustomerAddress address);
  Future<void> deleteAddress(CustomerAddress address);
}

class HttpAddressRepository implements AddressRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<CustomerAddress>> getAddresses() async {
    final response = await _apiClient.get('addresses/');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List;
      return data.map((item) => CustomerAddress.fromJson(item)).toList();
    }

    throw Exception('Failed to load addresses');
  }

  @override
  Future<CustomerAddress> createAddress(CustomerAddress address) async {
    final response = await _apiClient.post('addresses/', address.toJson());

    if (response.statusCode == 201) {
      return CustomerAddress.fromJson(jsonDecode(response.body));
    }

    throw Exception('Failed to save address');
  }

  @override
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

  @override
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
