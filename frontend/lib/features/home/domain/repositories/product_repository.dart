import 'dart:convert';
import 'package:hdk_core/hdk_core.dart';

abstract class ProductRepository {
  static ProductRepository? _instance;
  static ProductRepository get instance =>
      _instance ??= HttpProductRepository();
  static set instance(ProductRepository value) => _instance = value;

  Future<List<Product>> getProducts({bool fromCache = false});
  Future<List<Product>> getFeaturedProducts({bool fromCache = false});
  Future<List<Product>> getAddOns({bool fromCache = false});
  Future<List<Category>> getCategories({bool fromCache = false});
}

// Concrete class forward-declaration for default assignment
class HttpProductRepository implements ProductRepository {
  final ApiClient _apiClient = ApiClient();

  @override
  Future<List<Product>> getProducts({bool fromCache = false}) async {
    if (fromCache) {
      final cached = await LocalCache.getJson('cached_products');
      if (cached != null && cached is List) {
        return cached.map((item) => Product.fromJson(item)).toList();
      }
      return [];
    }

    try {
      final response = await _apiClient.get('products/');
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        await LocalCache.setJson('cached_products', list);
        return list.map((item) => Product.fromJson(item)).toList();
      }
    } catch (e) {
      final cached = await LocalCache.getJson('cached_products');
      if (cached != null && cached is List) {
        return cached.map((item) => Product.fromJson(item)).toList();
      }
      rethrow;
    }
    throw Exception("Failed to load products");
  }

  @override
  Future<List<Product>> getFeaturedProducts({bool fromCache = false}) async {
    if (fromCache) {
      final cached = await LocalCache.getJson('cached_featured_products');
      if (cached != null && cached is List) {
        return cached.map((item) => Product.fromJson(item)).toList();
      }
      return [];
    }

    try {
      final response = await _apiClient.get('products/featured/');
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        await LocalCache.setJson('cached_featured_products', list);
        final products = list.map((e) => Product.fromJson(e)).toList();
        if (products.isNotEmpty) return products;
      }
    } catch (_) {
      final cached = await LocalCache.getJson('cached_featured_products');
      if (cached != null && cached is List) {
        return cached.map((item) => Product.fromJson(item)).toList();
      }
    }
    return getProducts(fromCache: fromCache);
  }

  @override
  Future<List<Product>> getAddOns({bool fromCache = false}) async {
    if (fromCache) {
      final cached = await LocalCache.getJson('cached_addons');
      if (cached != null && cached is List) {
        return cached.map((item) => Product.fromJson(item)).toList();
      }
      return [];
    }

    try {
      final response = await _apiClient.get('products/addons/');
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        await LocalCache.setJson('cached_addons', list);
        return list.map((item) => Product.fromJson(item)).toList();
      }
    } catch (_) {
      final cached = await LocalCache.getJson('cached_addons');
      if (cached != null && cached is List) {
        return cached.map((item) => Product.fromJson(item)).toList();
      }
    }
    return [];
  }

  @override
  Future<List<Category>> getCategories({bool fromCache = false}) async {
    if (fromCache) {
      final cached = await LocalCache.getJson('cached_categories');
      if (cached != null && cached is List) {
        return cached.map((item) => Category.fromJson(item)).toList();
      }
      return [];
    }

    try {
      final response = await _apiClient.get('categories/');
      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        await LocalCache.setJson('cached_categories', list);
        return list.map((item) => Category.fromJson(item)).toList();
      }
    } catch (e) {
      final cached = await LocalCache.getJson('cached_categories');
      if (cached != null && cached is List) {
        return cached.map((item) => Category.fromJson(item)).toList();
      }
      rethrow;
    }
    throw Exception("Failed to load categories");
  }
}
