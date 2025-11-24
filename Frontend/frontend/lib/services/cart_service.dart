class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  List<Map<String, dynamic>> _cartItems = [];

  List<Map<String, dynamic>> get items => _cartItems;

  void addToCart(Map<String, dynamic> product) {
    // Check if product already exists in cart
    final existingIndex = _cartItems.indexWhere((item) => item['id'] == product['id']);
    
    if (existingIndex != -1) {
      // Product exists, increase quantity
      _cartItems[existingIndex]['quantity'] = (_cartItems[existingIndex]['quantity'] ?? 1) + 1;
    } else {
      // Add new product
      _cartItems.add({
        'id': product['id'],
        'name': product['name'],
        'description': product['description'],
        'price': product['price'] ?? 0.0,
        'quantity': 1,
      });
    }
  }

  void removeFromCart(int index) {
    if (index >= 0 && index < _cartItems.length) {
      _cartItems.removeAt(index);
    }
  }

  void clearCart() {
    _cartItems.clear();
  }

  double get totalPrice {
    return _cartItems.fold(0, (sum, item) => sum + (item['price'] * item['quantity']));
  }

  int get itemCount {
    return _cartItems.fold(0, (sum, item) => sum + (item['quantity'] as int));
  }
}