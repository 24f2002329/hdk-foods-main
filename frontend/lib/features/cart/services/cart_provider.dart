import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/models/product.dart';
import '../models/cart_item.dart';

const _kCartKey = 'hdk_cart_v1';

class CartProvider extends ChangeNotifier {
  final Map<int, CartItem> _items = {};

  CartProvider() {
    _loadCart();
  }

  List<CartItem> get items => _items.values.toList();

  int get itemCount =>
      _items.values.fold(0, (total, item) => total + item.quantity);

  double get totalAmount =>
      _items.values.fold(0, (total, item) => total + (item.product.price * item.quantity));

  bool contains(Product product) => _items.containsKey(product.id);

  int quantityFor(Product product) => _items[product.id]?.quantity ?? 0;

  void addProduct(Product product) {
    final existing = _items[product.id];
    _items[product.id] = existing == null
        ? CartItem(product: product, quantity: 1)
        : existing.copyWith(quantity: existing.quantity + 1);
    notifyListeners();
    _saveCart();
  }

  void increaseQuantity(Product product) => addProduct(product);

  void decreaseQuantity(Product product) {
    final existing = _items[product.id];
    if (existing == null) return;
    if (existing.quantity <= 1) {
      _items.remove(product.id);
    } else {
      _items[product.id] = existing.copyWith(quantity: existing.quantity - 1);
    }
    notifyListeners();
    _saveCart();
  }

  void removeProduct(Product product) {
    if (_items.remove(product.id) != null) {
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
        _items[item.product.id] = item;
      }
      notifyListeners();
    } catch (_) {}
  }
}
