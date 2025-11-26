import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000';

  Future<String?> _getAuthToken() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }

  Future<String> getUserRole(String uid) async {
    try {
      final token = await _getAuthToken();
      final response = await http.get(
        Uri.parse('$baseUrl/users/$uid/role'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['role'] ?? 'customer';
      }
      return 'customer';
    } catch (e) {
      print('Error getting user role: $e');
      return 'customer';
    }
  }

  Future<void> setUserRole(String uid, String role) async {
    try {
      final token = await _getAuthToken();
      await http.put(
        Uri.parse('$baseUrl/users/$uid/role'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'role': role}),
      );
    } catch (e) {
      print('Error setting user role: $e');
    }
  }

  Future<List<dynamic>> getProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collections/products'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['documents'] ?? [];
      }
      throw Exception('Failed to load products');
    } catch (e) {
      print('Error loading products: $e');
      rethrow;
    }
  }

  // Feature 4.4: Get User Orders
  Future<List<dynamic>> getUserOrders(String uid) async {
    try {
      final token = await _getAuthToken();
      // Backend should implement: GET /users/:uid/orders
      final response = await http.get(
        Uri.parse('$baseUrl/users/$uid/orders'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['orders'] ?? [];
      }
      // Fallback for demo if backend isn't ready (remove in production)
      return [];
    } catch (e) {
      print('Error loading orders: $e');
      // Return empty list so UI doesn't crash during demo if backend fails
      return [];
    }
  }
}

/*
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:3000';

  Future<List<dynamic>> getProducts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collections/products'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Got ${data['documents']?.length ?? 0} products');
        return data['documents'] ?? [];
      }
      throw Exception('Failed to load products: ${response.statusCode}');
    } catch (e) {
      print('Error loading products: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> getCategories() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collections/categories'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['documents'] ?? [];
      }
      throw Exception('Failed to load categories');
    } catch (e) {
      print('Error loading categories: $e');
      rethrow;
    }
  }
}
*/