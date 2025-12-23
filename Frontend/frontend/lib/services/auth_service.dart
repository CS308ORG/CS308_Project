import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cart_service.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  Map<String, dynamic>? _currentUser;
  String? _token;
  bool _initialized = false;

  bool get isLoggedIn => _currentUser != null;
  Map<String, dynamic>? get currentUser => _currentUser;
  String get userRole => _currentUser?['role'] ?? 'customer';
  
  // ✅ ADD THIS PUBLIC GETTER
  String? get token => _token;
  
  // Initialize and restore session from SharedPreferences
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('auth_token');
      final savedUserId = prefs.getString('user_id');
      
      if (savedToken != null && savedUserId != null) {
        // Restore token
        _token = savedToken;
        
        // Restore user data from SharedPreferences
        try {
          final userDataString = prefs.getString('user_data');
          if (userDataString != null) {
            _currentUser = jsonDecode(userDataString);
            // Load user's cart
            await CartService().loadCartForUser(savedUserId);
            notifyListeners();
          }
        } catch (e) {
          print("Error restoring session: $e");
          // Clear invalid session
          await prefs.remove('auth_token');
          await prefs.remove('user_id');
          await prefs.remove('user_data');
          _token = null;
        }
      }
    } catch (e) {
      print("Error initializing auth: $e");
    }
  }

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
          
          // SAVE TOKEN AND USER DATA TO SHARED PREFERENCES ⬇️
          if (userKey != null) {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('auth_token', userKey);
            await prefs.setString('user_id', userKey);
            await prefs.setString('user_data', jsonEncode(_currentUser)); // Store user data
            _token = userKey;
          }
          
          // Load user's saved cart
          await cartService.loadCartForUser(userKey);
          
          // Merge guest cart items into user's cart
          if (guestCartItems.isNotEmpty) {
            cartService.mergeCart(guestCartItems);
            // Clear guest cart after merge
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('cart_items_guest');
          }
          
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

    // CLEAR TOKEN AND USER DATA FROM SHARED PREFERENCES ⬇️
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('user_data');

    // 1. Switch context to Guest (unlogged)
    await CartService().loadCartForUser(null);

    // 2. Clear the guest cart immediately to ensure a fresh start
    await CartService().clearCart();

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