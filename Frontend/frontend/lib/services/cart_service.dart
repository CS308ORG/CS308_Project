import 'package:flutter/foundation.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  List<Map<String, dynamic>> _cartItems = [];

  List<Map<String, dynamic>> get items => _cartItems;

  // Add this method to CartService class
  void updateQuantity(int index, int quantity) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems[index]['quantity'] = quantity;
      notifyListeners();
    }
  }

  // Add item to local cart
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
        'sku':
            product['serial_number'] ??
            'SKU000', // Added for Order History display
      });
    }
    notifyListeners();
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
      notifyListeners();
    }
  }

  // Feature 4.1.2: Clear cart on logout
  void clearCart() {
    _cartItems.clear();
    notifyListeners();
  }

  

  // Feature 4.1.1: Merge backend cart into local (Simulated for Frontend)
  void mergeCart(List<dynamic> backendItems) {
    // In a real scenario, you send local items to backend, backend merges, returns result.
    // Here we simulate receiving the merged list.
    for (var item in backendItems) {
      // Logic to add backend items to local view
      addToCart(item);
    }
    notifyListeners();
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
