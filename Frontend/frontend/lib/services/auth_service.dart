import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import 'cart_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Map<String, dynamic>? _currentUser;
  String? _token;

  bool get isLoggedIn => _currentUser != null;
  Map<String, dynamic>? get currentUser => _currentUser;

  // Login using the Backend API (Fixes 4.0.2)
  Future<bool> login(String email, String password) async {
    try {
      // Save guest cart before login (to merge after login)
      final cartService = CartService();
      final guestCartItems = List<Map<String, dynamic>>.from(cartService.items);
      
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _currentUser = data['user'];
          final userKey = _resolveUserKey(_currentUser);
          
          // Load user's saved cart
          await cartService.loadCartForUser(userKey);
          
          // Merge guest cart items into user's cart
          if (guestCartItems.isNotEmpty) {
            cartService.mergeCart(guestCartItems);
            // Clear guest cart after merge
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('cart_items_guest');
          }
          
          // If your backend returns a token, store it here.
          // For now, we assume simple session based on user object existence.
          notifyListeners();
          return true;
        }
      }
      return false;
    } catch (e) {
      print("Login Error: $e");
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _token = null;
    await CartService().loadCartForUser(null);
    notifyListeners();
  }

  // Helper to get display name
  String get userName =>
      _currentUser?['name'] ?? _currentUser?['email']?.split('@')[0] ?? 'User';

  String? _resolveUserKey(Map<String, dynamic>? user) {
    if (user == null) return null;
    if (user['id'] != null) return user['id'].toString();
    if (user['user_id'] != null) return user['user_id'].toString();
    return null;
  }
}
