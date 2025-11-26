import 'package:flutter/material.dart';

class ReviewService {
  static final ReviewService _instance = ReviewService._internal();
  factory ReviewService() => _instance;
  ReviewService._internal();

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

  // Feature 4.1.0: Add public review (Instant)
  void addPublicReview(int productId, Map<String, dynamic> review) {
    if (!_reviews.containsKey(productId)) {
      _reviews[productId] = [];
    }
    // Add to the beginning of the list so it appears first
    _reviews[productId]!.insert(0, review);
  }

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
}
