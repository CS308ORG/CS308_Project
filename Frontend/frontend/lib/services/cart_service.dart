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
    _storageKey = userId == null ? _guestKey : 'cart_items_${userId.toString()}';
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
    final existingIndex = _cartItems.indexWhere(
      (item) => item['id'] == product['id'],
    );

    if (existingIndex != -1) {
      _cartItems[existingIndex]['quantity'] =
          (_cartItems[existingIndex]['quantity'] ?? 1) + 1;
    } else {
      _cartItems.add({
        'id': product['id'],
        'name': product['name'],
        'description': product['description'],
        'price': product['price'] ?? 0.0,
        'quantity': 1,
        'sku': product['serial_number'] ?? 'SKU000',
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

  void mergeCart(List<dynamic> backendItems) {
    for (var item in backendItems) {
      addToCart(item);
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
