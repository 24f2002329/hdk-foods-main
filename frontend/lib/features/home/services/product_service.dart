import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/config/api_config.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/category.dart';

class ProductService {
  static Future<List<Product>> getProducts() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/products/"),
    );

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((item) => Product.fromJson(item))
          .toList();
    }

    throw Exception("Failed to load products");
  }

  static Future<List<Product>> getFeaturedProducts() async {
    try {
      final response = await http.get(Uri.parse("${ApiConfig.baseUrl}/products/featured/"));
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List).map((e) => Product.fromJson(e)).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (_) {}
    // Fallback to all products if featured endpoint fails or returns empty
    return getProducts();
  }

  static Future<List<Product>> getAddOns() async {
    try {
      final response = await http.get(
        Uri.parse("${ApiConfig.baseUrl}/products/addons/"),
      );
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List)
            .map((item) => Product.fromJson(item))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Category>> getCategories() async {
    final response = await http.get(
      Uri.parse("${ApiConfig.baseUrl}/categories/"),
    );

    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((item) => Category.fromJson(item))
          .toList();
    }

    throw Exception("Failed to load categories");
  }
}
