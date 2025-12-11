import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

  final String baseUrl = 'http://localhost:3000';

  // ========================================
  // EXISTING LOCAL STORAGE (Keep for backward compatibility)
  // ========================================
  
  // Key: Product ID, Value: List of reviews
  final Map<int, List<Map<String, dynamic>>> _reviews = {};
  
  // Key: User ID, Value: Pending review for a product
  final Map<String, List<Map<String, dynamic>>> _pendingReviews = {};

  List<Map<String, dynamic>> getReviews(int productId) {
    // Initialize dummy data if empty
    if (!_reviews.containsKey(productId)) {
      _reviews[productId] = [
        {'user': 'User1', 'rating': 5, 'text': 'Great product!'},
        {'user': 'User2', 'rating': 4, 'text': 'Good value.'},
      ];
    }
    return _reviews[productId]!;
  }

  // Add public review (Instant)
  void addPublicReview(int productId, Map<String, dynamic> review) {
    if (!_reviews.containsKey(productId)) {
      _reviews[productId] = [];
    }
    // Add to the beginning of the list so it appears first
    _reviews[productId]!.insert(0, review);
  }

  // Add pending review
  void addPendingReview(String userId, int productId, int rating, String text) {
    if (!_pendingReviews.containsKey(userId)) {
      _pendingReviews[userId] = [];
    }
    // Replace existing pending review for this product
    _pendingReviews[userId]!.removeWhere((r) => r['productId'] == productId);
    _pendingReviews[userId]!.add({
      'productId': productId,
      'rating': rating,
      'text': text,
      'user': userId,
    });
  }

  Map<String, dynamic>? getPendingReview(String userId, int productId) {
    if (!_pendingReviews.containsKey(userId)) return null;
    try {
      return _pendingReviews[userId]!.firstWhere(
        (r) => r['productId'] == productId,
      );
    } catch (e) {
      return null;
    }
  }

  void removePendingReview(String userId, int productId) {
    if (_pendingReviews.containsKey(userId)) {
      _pendingReviews[userId]!.removeWhere((r) => r['productId'] == productId);
    }
  }

  // ========================================
  // NEW: BACKEND API METHODS (For Product Manager Moderation)
  // ========================================

  /// Fetch pending reviews from backend (for Product Manager moderation)
  Future<List<dynamic>> getPendingReviewsFromBackend() async {
    final token = AuthService().token;
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/reviews/moderation'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['reviews'] ?? [];
    } else {
      throw Exception('Failed to load pending reviews: ${response.body}');
    }
  }

  /// Check if user is eligible to review a product (has received it)
  Future<bool> checkReviewEligibility(String userId, String productId) async {
    final token = AuthService().token;
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId/products/$productId/eligibility'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['canReview'] ?? false;
    } else {
      throw Exception('Failed to check eligibility: ${response.body}');
    }
  }

  /// Approve a review (Product Manager only)
  Future<void> approveReview(String reviewId, {String? reason}) async {
    final token = AuthService().token;
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('$baseUrl/reviews/$reviewId/approve'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'decision': 'approved',
        'reason': reason,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to approve review: ${response.body}');
    }
  }

  /// Reject a review (Product Manager only)
  Future<void> rejectReview(String reviewId, String reason) async {
    final token = AuthService().token;
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('$baseUrl/reviews/$reviewId/approve'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'decision': 'rejected',
        'reason': reason,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to reject review: ${response.body}');
    }
  }

  /// Get product details from backend
  Future<Map<String, dynamic>> getProductDetails(String productId) async {
    final token = AuthService().token;

    final response = await http.get(
      Uri.parse('$baseUrl/collections/products'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final products = data['documents'] ?? [];
      
      // Find product by ID
      for (var product in products) {
        if (product['product_id'].toString() == productId.toString()) {
          return product;
        }
      }
      return {'name': 'Product #$productId', 'product_id': productId};
    }
    return {'name': 'Product #$productId', 'product_id': productId};
  }

  /// Fetch public reviews for a product from backend
  Future<List<dynamic>> getReviewsFromBackend(String productId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/products/$productId/reviews'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['reviews'] ?? [];
      } else {
        return [];
      }
    } catch (e) {
      print('Error fetching reviews: $e');
      return [];
    }
  }

  /// Submit a review to backend
  Future<void> submitReviewToBackend(int productId, int rating, String comment) async {
    final token = AuthService().token;
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/reviews'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: json.encode({
        'product_id': productId,
        'rating': rating,
        'comment': comment.trim(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to submit review: ${response.body}');
    }
  }
}