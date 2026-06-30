import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/cart/services/cart_provider.dart';
import 'package:hdk_core/hdk_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('CartProvider manages quantities, totals, and clearing', () {
    final cart = CartProvider();
    final product = Product(
      id: 1,
      name: 'Classic Boba',
      description: 'Milk tea with tapioca pearls',
      image: '',
      price: 120,
      isFeatured: true,
      preparationTime: 10,
      modifierGroups: const [],
    );

    cart.addProduct(product);
    cart.increaseQuantity(product);

    expect(cart.itemCount, 2);
    expect(cart.quantityFor(product), 2);
    expect(cart.totalAmount, 240);

    cart.decreaseQuantity(product);

    expect(cart.itemCount, 1);
    expect(cart.totalAmount, 120);

    cart.removeProduct(product);

    expect(cart.itemCount, 0);
    expect(cart.items, isEmpty);

    cart.addProduct(product);
    cart.clearCart();

    expect(cart.itemCount, 0);
    expect(cart.totalAmount, 0);
  });
}
