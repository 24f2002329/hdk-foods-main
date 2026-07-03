import 'package:hdk_core/hdk_core.dart';
import '../../domain/repositories/product_repository.dart';

class ProductService {
  static Future<List<Product>> getProducts({bool fromCache = false}) =>
      ProductRepository.instance.getProducts(fromCache: fromCache);

  static Future<List<Product>> getFeaturedProducts({bool fromCache = false}) =>
      ProductRepository.instance.getFeaturedProducts(fromCache: fromCache);

  static Future<List<Product>> getAddOns({bool fromCache = false}) =>
      ProductRepository.instance.getAddOns(fromCache: fromCache);

  static Future<List<Category>> getCategories({bool fromCache = false}) =>
      ProductRepository.instance.getCategories(fromCache: fromCache);
}
