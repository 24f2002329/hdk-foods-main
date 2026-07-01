import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';

abstract class ProductRepository {
  static ProductRepository? _instance;
  static ProductRepository get instance => _instance ??= HttpProductRepository();
  static set instance(ProductRepository value) => _instance = value;

  Future<List<Product>> getProducts();
  Future<List<Product>> getFeaturedProducts();
  Future<List<Product>> getAddOns();
  Future<List<Category>> getCategories();
}

// Concrete class forward-declaration for default assignment
class HttpProductRepository implements ProductRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<Product>> getProducts() async {
    final response = await _apiClient.get('products/');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => Product.fromJson(item)).toList();
    }
    throw Exception("Failed to load products");
  }

  @override
  Future<List<Product>> getFeaturedProducts() async {
    try {
      final response = await _apiClient.get('products/featured/');
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        final products = list.map((e) => Product.fromJson(e)).toList();
        if (products.isNotEmpty) return products;
      }
    } catch (_) {}
    return getProducts();
  }

  @override
  Future<List<Product>> getAddOns() async {
    try {
      final response = await _apiClient.get('products/addons/');
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((item) => Product.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  @override
  Future<List<Category>> getCategories() async {
    final response = await _apiClient.get('categories/');
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(response.body);
      return list.map((item) => Category.fromJson(item)).toList();
    }
    throw Exception("Failed to load categories");
  }
}
