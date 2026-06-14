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
