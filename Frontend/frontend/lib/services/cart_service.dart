import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal() {
    loadCartForUser(null); // ensure guest cart restored on app start
  }

  static const String _guestKey = 'cart_items_guest';
  String _storageKey = _guestKey;

  List<Map<String, dynamic>> _cartItems = [];

  List<Map<String, dynamic>> get items => _cartItems;

  Future<void> loadCartForUser(String? userId) async {
    _storageKey = userId == null
        ? _guestKey
        : 'cart_items_${userId.toString()}';
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw != null) {
      try {
        final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
        _cartItems = decoded
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      } catch (_) {
        _cartItems = [];
      }
    } else {
      _cartItems = [];
    }
    notifyListeners();
  }

  void _persistCart() {
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString(_storageKey, jsonEncode(_cartItems)),
    );
  }

  void updateQuantity(int index, int quantity) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index]['quantity'] = quantity;
      notifyListeners();
      _persistCart();
    }
  }

  void addToCart(Map<String, dynamic> product) {
    final productId = product['id'] ?? product['product_id'];
    final existingIndex = _cartItems.indexWhere(
      (item) =>
          (item['id'] ?? item['product_id']).toString() == productId.toString(),
    );

    if (existingIndex != -1) {
      _cartItems[existingIndex]['quantity'] =
          (_cartItems[existingIndex]['quantity'] ?? 1) + 1;
      // Update stock info in case it changed
      if (product['quantity_in_stock'] != null) {
        _cartItems[existingIndex]['quantity_in_stock'] =
            product['quantity_in_stock'];
      }
    } else {
      _cartItems.add({
        'id': productId,
        'product_id': productId,
        'name': product['name'],
        'description': product['description'],
        'price': product['price'] ?? 0.0,
        'quantity': 1,
        'quantity_in_stock': product['quantity_in_stock'] ?? 0,
        'sku': product['serial_number'] ?? product['sku'] ?? 'SKU000',
      });
    }
    notifyListeners();
    _persistCart();
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
      _persistCart();
    }
  }

  Future<void> clearCart({bool removeStoredData = true}) async {
    _cartItems.clear();
    notifyListeners();
    if (removeStoredData) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    }
  }

  void mergeCart(List<dynamic> guestItems) {
    // Merge guest cart items while preserving quantities
    for (var guestItem in guestItems) {
      final productId = guestItem['id'] ?? guestItem['product_id'];
      final guestQuantity = guestItem['quantity'] ?? 1;

      final existingIndex = _cartItems.indexWhere(
        (item) =>
            (item['id'] ?? item['product_id']).toString() ==
            productId.toString(),
      );

      if (existingIndex != -1) {
        // If item already exists, add guest quantity to existing quantity
        final currentQuantity = _cartItems[existingIndex]['quantity'] ?? 1;
        _cartItems[existingIndex]['quantity'] = currentQuantity + guestQuantity;
      } else {
        // If item doesn't exist, add it with guest quantity
        _cartItems.add({
          'id': productId,
          'product_id': productId,
          'name': guestItem['name'],
          'description': guestItem['description'],
          'price': guestItem['price'] ?? 0.0,
          'quantity': guestQuantity,
          'quantity_in_stock': guestItem['quantity_in_stock'] ?? 0,
          'sku': guestItem['sku'] ?? guestItem['serial_number'] ?? 'SKU000',
        });
      }
    }
    notifyListeners();
    _persistCart();
  }

  double get totalPrice {
    return _cartItems.fold(
      0,
      (sum, item) => sum + (item['price'] * item['quantity']),
    );
  }

  int get itemCount {
    return _cartItems.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }
}
