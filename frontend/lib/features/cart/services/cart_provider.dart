import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/product.dart';
import '../models/cart_item.dart';

const _kCartKey = 'hdk_cart_v1';

class CartProvider extends ChangeNotifier {
  final Map<String, CartItem> _items = {};

  CartProvider() {
    _loadCart();
  }

  List<CartItem> get items => _items.values.toList();

  int get itemCount =>
      _items.values.fold(0, (total, item) => total + item.quantity);

  double get totalAmount =>
      _items.values.fold(0, (total, item) => total + ((item.product.price + item.customizationPrice) * item.quantity));

  bool contains(Product product) =>
      _items.values.any((item) => item.product.id == product.id);

  int quantityFor(Product product) => _items.values
      .where((item) => item.product.id == product.id)
      .fold(0, (total, item) => total + item.quantity);

  void addProduct(
    Product product, {
    int quantity = 1,
    String? size,
    String? spiceLevel,
    List<String> customizations = const [],
    double customizationPrice = 0.0,
    String? notes,
  }) {
    final item = CartItem(
      product: product,
      quantity: quantity,
      size: size,
      spiceLevel: spiceLevel,
      customizations: customizations,
      customizationPrice: customizationPrice,
      notes: notes,
    );
    final key = item.cartId;
    final existing = _items[key];
    if (existing == null) {
      _items[key] = item;
    } else {
      _items[key] = existing.copyWith(quantity: existing.quantity + quantity);
    }
    notifyListeners();
    _saveCart();
  }

  void increaseQuantity(Product product) {
    final existing = _items.values.firstWhere(
      (item) => item.product.id == product.id,
      orElse: () => CartItem(product: product, quantity: 0),
    );
    if (existing.quantity == 0) {
      addProduct(product);
    } else {
      increaseQuantityForCartId(existing.cartId);
    }
  }

  void increaseQuantityForCartId(String cartId) {
    final existing = _items[cartId];
    if (existing == null) return;
    _items[cartId] = existing.copyWith(quantity: existing.quantity + 1);
    notifyListeners();
    _saveCart();
  }

  void decreaseQuantity(Product product) {
    final matching = _items.values.where((item) => item.product.id == product.id).toList();
    if (matching.isEmpty) return;
    decreaseQuantityForCartId(matching.last.cartId);
  }

  void decreaseQuantityForCartId(String cartId) {
    final existing = _items[cartId];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      _items.remove(cartId);
    } else {
      _items[cartId] = existing.copyWith(quantity: existing.quantity - 1);
    }
    notifyListeners();
    _saveCart();
  }

  void removeProduct(Product product) {
    bool changed = false;
    _items.removeWhere((key, item) {
      if (item.product.id == product.id) {
        changed = true;
        return true;
      }
      return false;
    });
    if (changed) {
      notifyListeners();
      _saveCart();
    }
  }

  void removeProductByCartId(String cartId) {
    if (_items.remove(cartId) != null) {
      notifyListeners();
      _saveCart();
    }
  }

  void clearCart() {
    if (_items.isEmpty) return;
    _items.clear();
    notifyListeners();
    _saveCart();
  }

  Future<void> _saveCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _items.values.map((e) => e.toJson()).toList();
      await prefs.setString(_kCartKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<void> _loadCart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCartKey);
      if (raw == null) return;
      final list = jsonDecode(raw) as List<dynamic>;
      for (final json in list) {
        final item = CartItem.fromJson(json as Map<String, dynamic>);
        _items[item.cartId] = item;
      }
      notifyListeners();
    } catch (_) {}
  }
}
