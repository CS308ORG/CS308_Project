import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:3000';
  Future<String?> _getAuthToken() async {
    // 1. Try Firebase Auth (for Registered Users)
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) return await user.getIdToken();
    // 2. Try AuthService (for Seeded Users)
    if (AuthService().isLoggedIn) {
      // Send the user_id as the token.
      // The backend will recognize it.
      return AuthService().currentUser?['id']?.toString() ??
          AuthService().currentUser?['user_id']?.toString();
    }
    return null;
  }

  // --- EXISTING METHODS ---

  Future<String> getUserRole(String uid) async {
    // Simplified for brevity
    return 'customer';
  }

  Future<void> setUserRole(String uid, String role) async {
    /* ... */
  }

  Future<List<dynamic>> getProducts() async {
    final response = await http.get(Uri.parse('$baseUrl/collections/products'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body)['documents'] ?? [];
    }
    return [];
  }

  // --- UPDATED: GET REAL ORDERS FROM BACKEND ---
  Future<List<dynamic>> getUserOrders(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) {
        print("No auth token available for orders");
        return [];
      }

      final response = await http.get(
        Uri.parse('$baseUrl/users/$uid/orders'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['orders'] ?? [];
      } else {
        print(
          "Failed to fetch orders: ${response.statusCode} - ${response.body}",
        );
      }
    } catch (e) {
      print("Error fetching user orders: $e");
    }
    return [];
  }

  // --- NEW REVIEW METHODS ---

  // 1. Get Public Reviews
  Future<List<dynamic>> getPublicReviews(dynamic productId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/$productId/reviews'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['reviews'] ?? [];
      }
    } catch (e) {
      print("Error fetching reviews: $e");
    }
    return [];
  }

  // 2. Get My Pending Reviews
  Future<List<dynamic>> getMyPendingReviews() async {
    try {
      final token = await _getAuthToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/my-pending-reviews'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body)['reviews'] ?? [];
      }
    } catch (e) {
      print("Error fetching pending reviews: $e");
    }
    return [];
  }

  // 3. Post Review
  Future<bool> postReview(dynamic productId, int rating, String comment) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/reviews'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'product_id': productId,
          'rating': rating,
          'comment': comment,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error posting review: $e");
      return false;
    }
  }

  // 4. Delete Review
  Future<bool> deleteReview(String reviewId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$baseUrl/reviews/$reviewId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Error deleting review: $e");
      return false;
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