import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../core/storage/token_storage.dart';
import '../models/product.dart';

class ProductService {
  static final String _base = ApiConfig.baseUrl;

  Future<Map<String, String>> _headers() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception('Not logged in');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Category>> getCategories() async {
    final response = await http.get(
      Uri.parse('$_base/categories/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load categories');
  }

  Future<List<Product>> getProducts() async {
    final response = await http.get(
      Uri.parse('$_base/products/?all=1'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load products');
  }

  Future<Product> toggleAvailability(int productId) async {
    final response = await http.patch(
      Uri.parse('$_base/products/$productId/toggle/'),
      headers: await _headers(),
    );
    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to toggle product');
  }

  Future<Product> createProduct(Map<String, dynamic> data) async {
    final response = await http.post(
      Uri.parse('$_base/products/create/'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 201) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create product: ${response.body}');
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final response = await http.patch(
      Uri.parse('$_base/products/$id/update/'),
      headers: await _headers(),
      body: jsonEncode(data),
    );
    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update product: ${response.body}');
  }

  Future<void> deleteProduct(int id) async {
    final response = await http.delete(
      Uri.parse('$_base/products/$id/delete/'),
      headers: await _headers(),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete product: ${response.body}');
    }
  }
}
