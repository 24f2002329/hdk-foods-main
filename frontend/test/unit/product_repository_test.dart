import 'package:flutter_test/flutter_test.dart';
import 'package:hdk_core/hdk_core.dart';
import 'package:frontend/features/home/domain/repositories/product_repository.dart';

class MockProductRepository implements ProductRepository {
  @override
  Future<List<Product>> getProducts() async {
    return [
      Product(
        id: 101,
        name: 'Mock Product',
        description: 'Test description',
        image: '',
        price: 99,
        isFeatured: false,
        preparationTime: 5,
        modifierGroups: const [],
      )
    ];
  }

  @override
  Future<List<Product>> getFeaturedProducts() async => [];

  @override
  Future<List<Product>> getAddOns() async => [];

  @override
  Future<List<Category>> getCategories() async => [];
}

void main() {
  test('ProductRepository supports injection and mock overrides', () async {
    // 1. Verify default type is HttpProductRepository
    expect(ProductRepository.instance, isA<HttpProductRepository>());

    // 2. Inject mock repository
    final mockRepo = MockProductRepository();
    ProductRepository.instance = mockRepo;

    // 3. Verify mock repository is utilized
    expect(ProductRepository.instance, isA<MockProductRepository>());
    final products = await ProductRepository.instance.getProducts();
    
    expect(products.length, 1);
    expect(products.first.name, 'Mock Product');
    expect(products.first.price, 99);
  });
}
