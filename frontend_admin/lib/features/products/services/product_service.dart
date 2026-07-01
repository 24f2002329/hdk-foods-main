import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'package:hdk_core/hdk_core.dart';

class ProductService {
  static final String _base = ApiConfig.baseUrl;

  Future<List<Category>> getCategories() async {
    final response = await ApiClient().get('$_base/categories/');
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load categories');
  }

  Future<Category> createCategory(String name) async {
    final response = await ApiClient().post('$_base/categories/', {'name': name});
    if (response.statusCode == 201) {
      return Category.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Failed to create category: ${response.body}');
  }

  Future<void> deleteCategory(int id) async {
    final response = await ApiClient().delete('$_base/categories/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete category: ${response.body}');
    }
  }

  Future<List<Product>> getProducts() async {
    final response = await ApiClient().get('$_base/products/?all=1');
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load products');
  }

  Future<Product> toggleAvailability(int productId) async {
    final response = await ApiClient().patch('$_base/products/$productId/toggle/', {});
    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to toggle product');
  }

  Future<Product> createProduct(Map<String, dynamic> data) async {
    final response = await ApiClient().post('$_base/products/create/', data);
    if (response.statusCode == 201) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create product: ${response.body}');
  }

  Future<Product> updateProduct(int id, Map<String, dynamic> data) async {
    final response = await ApiClient().patch('$_base/products/$id/update/', data);
    if (response.statusCode == 200) {
      return Product.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update product: ${response.body}');
  }

  Future<void> deleteProduct(int id) async {
    final response = await ApiClient().delete('$_base/products/$id/delete/');
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

  Future<List<ModifierGroup>> getModifierGroups() async {
    final response = await ApiClient().get('$_base/modifiers/groups/');
    if (response.statusCode == 200) {
      return (jsonDecode(response.body) as List)
          .map((e) => ModifierGroup.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    throw Exception('Failed to load modifier groups: ${response.body}');
  }

  Future<ModifierGroup> createModifierGroup(Map<String, dynamic> data) async {
    final response = await ApiClient().post('$_base/modifiers/groups/', data);
    if (response.statusCode == 201) {
      return ModifierGroup.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create modifier group: ${response.body}');
  }

  Future<ModifierGroup> updateModifierGroup(int id, Map<String, dynamic> data) async {
    final response = await ApiClient().patch('$_base/modifiers/groups/$id/', data);
    if (response.statusCode == 200) {
      return ModifierGroup.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update modifier group: ${response.body}');
  }

  Future<void> deleteModifierGroup(int id) async {
    final response = await ApiClient().delete('$_base/modifiers/groups/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete modifier group: ${response.body}');
    }
  }

  Future<ModifierOption> createModifierOption(Map<String, dynamic> data) async {
    final response = await ApiClient().post('$_base/modifiers/options/', data);
    if (response.statusCode == 201) {
      return ModifierOption.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to create modifier option: ${response.body}');
  }

  Future<ModifierOption> updateModifierOption(int id, Map<String, dynamic> data) async {
    final response = await ApiClient().patch('$_base/modifiers/options/$id/', data);
    if (response.statusCode == 200) {
      return ModifierOption.fromJson(jsonDecode(response.body));
    }
    throw Exception('Failed to update modifier option: ${response.body}');
  }

  Future<void> deleteModifierOption(int id) async {
    final response = await ApiClient().delete('$_base/modifiers/options/$id/');
    if (response.statusCode != 204) {
      throw Exception('Failed to delete modifier option: ${response.body}');
    }
  }
}
