import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

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

  Future<Category> createCategory(String name) async {
    final response = await http.post(
      Uri.parse('$_base/categories/'),
      headers: await _headers(),
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 201) {
      return Category.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create category: ${response.body}');
  }

  Future<void> deleteCategory(int id) async {
    final response = await http.delete(
      Uri.parse('$_base/categories/$id/'),
      headers: await _headers(),
    );
    if (response.statusCode != 204) {
      throw Exception('Failed to delete category: ${response.body}');
    }
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

  Future<Product> uploadImage(int productId, File imageFile) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null) throw Exception('Not logged in');

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/products/$productId/image/'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    final extension = imageFile.path.split('.').last.toLowerCase();
    String mimeType = 'image/jpeg';
    if (extension == 'png') {
      mimeType = 'image/png';
    } else if (extension == 'gif') {
      mimeType = 'image/gif';
    } else if (extension == 'webp') {
      mimeType = 'image/webp';
    } else if (extension == 'bmp') {
      mimeType = 'image/bmp';
    }

    final multipartFile = await http.MultipartFile.fromPath(
      'image',
      imageFile.path,
      contentType: MediaType.parse(mimeType),
    );
    request.files.add(multipartFile);

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to upload image: ${response.body}');
  }
}
