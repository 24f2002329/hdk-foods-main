import 'package:flutter/foundation.dart';

import '../../../shared/models/product.dart';
import '../models/cart_item.dart';

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};

  List<CartItem> get items => _items.values.toList();

  int get itemCount {
    return _items.values.fold(
      0,
      (total, item) => total + item.quantity,
    );
  }

  double get totalAmount {
    return _items.values.fold(
      0,
      (total, item) => total + (item.product.price * item.quantity),
    );
  }

  bool contains(Product product) {
    return _items.containsKey(product.id);
  }

  int quantityFor(Product product) {
    return _items[product.id]?.quantity ?? 0;
  }

  void addProduct(Product product) {
    final existingItem = _items[product.id];

    if (existingItem == null) {
      _items[product.id] = CartItem(
        product: product,
        quantity: 1,
      );
    } else {
      _items[product.id] = existingItem.copyWith(
        quantity: existingItem.quantity + 1,
      );
    }

    notifyListeners();
  }

  void increaseQuantity(Product product) {
    addProduct(product);
  }

  void decreaseQuantity(Product product) {
    final existingItem = _items[product.id];

    if (existingItem == null) {
      return;
    }

    if (existingItem.quantity <= 1) {
      _items.remove(product.id);
    } else {
      _items[product.id] = existingItem.copyWith(
        quantity: existingItem.quantity - 1,
      );
    }

    notifyListeners();
  }

  void removeProduct(Product product) {
    if (_items.remove(product.id) != null) {
      notifyListeners();
    }
  }

  void clearCart() {
    if (_items.isEmpty) {
      return;
    }

    _items.clear();
    notifyListeners();
  }
}