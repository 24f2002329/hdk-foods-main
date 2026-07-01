import 'package:hdk_core/hdk_core.dart';
import '../../domain/repositories/product_repository.dart';

class ProductService {
  static Future<List<Product>> getProducts() =>
      ProductRepository.instance.getProducts();

  static Future<List<Product>> getFeaturedProducts() =>
      ProductRepository.instance.getFeaturedProducts();

  static Future<List<Product>> getAddOns() =>
      ProductRepository.instance.getAddOns();

  static Future<List<Category>> getCategories() =>
      ProductRepository.instance.getCategories();
}
