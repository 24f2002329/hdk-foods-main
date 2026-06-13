import 'dart:convert';

import 'package:http/http.dart'
    as http;

import '../../../shared/models/product.dart';
import '../../../shared/models/category.dart';

class ProductService {
  static Future<List<Product>>
      getProducts() async {
    final response =
        await http.get(
      Uri.parse(
        "http://10.53.14.18:8000/api/products/",
      ),
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(response.body);

      return (data as List)
          .map(
            (item) =>
                Product.fromJson(item),
          )
          .toList();
    }

    throw Exception(
      "Failed to load products",
    );
  }




  static Future<List<Category>>
      getCategories() async {
    final response =
        await http.get(
      Uri.parse(
        "http://10.53.14.18:8000/api/categories/",
      ),
    );

    if (response.statusCode == 200) {
      final data =
          jsonDecode(response.body);

      return (data as List)
          .map(
            (item) =>
                Category.fromJson(item),
          )
          .toList();
    }

    throw Exception(
      "Failed to load categories",
    );
  }
}