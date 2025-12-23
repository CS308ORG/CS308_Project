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
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collections/products'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('Products response: ${data.toString()}');
        return data['documents'] ?? [];
      } else {
        print(
          'Failed to fetch products: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('Error fetching products: $e');
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

  // --- REVIEW METHODS ---

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

  // 1b. Get Pending Reviews for Moderation (Product Manager)
  Future<List<dynamic>> getPendingReviewsForModeration() async {
    try {
      final token = await _getAuthToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/reviews/moderation'),
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

  // 1c. Update review approval status
  Future<bool> updateReviewApproval(
    String reviewId,
    String decision, {
    String? reason,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/reviews/$reviewId/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'decision': decision,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error updating review approval: $e");
      return false;
    }
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

  // 5. Check Eligibility
  // Checks if the user ordered this product and it was delivered
  Future<bool> checkReviewEligibility(String uid, dynamic productId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false; // Not logged in

      final response = await http.get(
        Uri.parse('$baseUrl/users/$uid/products/$productId/eligibility'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['canReview'] == true;
      }
    } catch (e) {
      print("Error checking eligibility: $e");
    }
    return false;
  }

  // 6. Checkout - Create order from cart items
  Future<Map<String, dynamic>?> checkout(
    String userId,
    List<Map<String, dynamic>> cartItems,
  ) async {
    try {
      // Convert cart items to checkout format
      final items = cartItems
          .map(
            (item) => {
              'product_id': item['id'],
              'quantity': item['quantity'] ?? 1,
            },
          )
          .toList();

      final response = await http.post(
        Uri.parse('$baseUrl/checkout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'user_id': userId, 'items': items}),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        print("Checkout failed: ${response.statusCode} - ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error during checkout: $e");
      return null;
    }
  }

  // --- REFUND METHODS ---

  // Request refund for a product in an order
  Future<Map<String, dynamic>?> requestRefund(
    String orderId,
    dynamic productId,
    String reason,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return null;

      final response = await http.post(
        Uri.parse('$baseUrl/refunds/request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'order_id': orderId,
          'product_id': productId,
          'reason': reason,
        }),
      );

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to request refund');
      }
    } catch (e) {
      print("Error requesting refund: $e");
      rethrow;
    }
  }

  // Get user's refund requests
  Future<List<dynamic>> getUserRefunds(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/users/$uid/refunds'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['refunds'] ?? [];
      }
    } catch (e) {
      print("Error fetching user refunds: $e");
    }
    return [];
  }

  // Get all refunds (Sales Manager)
  Future<List<dynamic>> getAllRefunds({String? status}) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return [];

      String url = '$baseUrl/refunds';
      if (status != null) {
        url += '?status=$status';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['refunds'] ?? [];
      }
    } catch (e) {
      print("Error fetching refunds: $e");
    }
    return [];
  }

  // Approve or reject refund (Sales Manager)
  Future<bool> processRefund(
    String refundId,
    String decision, {
    String? reason,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/refunds/$refundId/approve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'decision': decision,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error processing refund: $e");
      return false;
    }
  }

  // --- WISHLIST METHODS ---

  // Get user's wishlist
  Future<List<dynamic>> getWishlist(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/users/$uid/wishlist'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['wishlist'] ?? [];
      }
    } catch (e) {
      print("Error fetching wishlist: $e");
    }
    return [];
  }

  // Add product to wishlist
  Future<bool> addToWishlist(String uid, String productId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/users/$uid/wishlist'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'product_id': productId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error adding to wishlist: $e");
      return false;
    }
  }

  // Remove product from wishlist
  Future<bool> removeFromWishlist(String uid, String productId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.delete(
        Uri.parse('$baseUrl/users/$uid/wishlist/$productId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error removing from wishlist: $e");
      return false;
    }
  }

  // --- ORDER CANCELLATION METHODS ---

  // Cancel order (only if processing)
  Future<bool> cancelOrder(String orderId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/orders/$orderId/cancel'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error cancelling order: $e");
      return false;
    }
  }

  // --- USER INFORMATION METHODS ---

  // Get user information
  Future<Map<String, dynamic>?> getUserInfo(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/users/$uid/info'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print("Error fetching user info: $e");
    }
    return null;
  }

  // Update user information
  Future<bool> updateUserInfo(String uid, Map<String, dynamic> updates) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/users/$uid/info'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error updating user info: $e");
      return false;
    }
  }

  // --- SALES MANAGER METHODS ---

  // Get all products for sales manager
  Future<List<dynamic>> getAllProducts() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/products'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['products'] ?? [];
      }
    } catch (e) {
      print("Error fetching products: $e");
    }
    return [];
  }

  // 11.1 - Set product price (Sales Manager)
  Future<Map<String, dynamic>?> setProductPrice(
    String productId,
    double price,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return null;

      final response = await http.put(
        Uri.parse('$baseUrl/products/$productId/price'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'price': price}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to update price');
      }
    } catch (e) {
      print("Error setting product price: $e");
      rethrow;
    }
  }

  // 11.2 - Set discount on product (Sales Manager)
  // 11.3 - System notifies wishlist users automatically
  Future<Map<String, dynamic>?> setProductDiscount(
    String productId,
    double discountRate,
  ) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return null;

      final response = await http.put(
        Uri.parse('$baseUrl/products/$productId/discount'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'discount_rate': discountRate}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to apply discount');
      }
    } catch (e) {
      print("Error setting product discount: $e");
      rethrow;
    }
  }

  // Remove discount from product
  Future<Map<String, dynamic>?> removeProductDiscount(String productId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return null;

      final response = await http.delete(
        Uri.parse('$baseUrl/products/$productId/discount'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to remove discount');
      }
    } catch (e) {
      print("Error removing product discount: $e");
      rethrow;
    }
  }

  // --- NOTIFICATION METHODS (11.3 - In-App Notifications) ---

  // Get user's notifications
  Future<List<dynamic>> getNotifications(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return [];

      final response = await http.get(
        Uri.parse('$baseUrl/users/$uid/notifications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['notifications'] ?? [];
      }
    } catch (e) {
      print("Error fetching notifications: $e");
    }
    return [];
  }

  // Get unread notification count
  Future<int> getUnreadNotificationCount(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return 0;

      final response = await http.get(
        Uri.parse('$baseUrl/users/$uid/notifications/unread-count'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['count'] ?? 0;
      }
    } catch (e) {
      print("Error fetching unread count: $e");
    }
    return 0;
  }

  // Mark notification as read
  Future<bool> markNotificationAsRead(String notificationId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error marking notification as read: $e");
      return false;
    }
  }

  // Mark all notifications as read
  Future<bool> markAllNotificationsAsRead(String uid) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return false;

      final response = await http.put(
        Uri.parse('$baseUrl/users/$uid/notifications/read-all'),
        headers: {'Authorization': 'Bearer $token'},
      );

      return response.statusCode == 200;
    } catch (e) {
      print("Error marking all notifications as read: $e");
      return false;
    }
  }

  // --- INVOICE MANAGEMENT METHODS (11.4) ---

  // Get invoices with date range filter
  Future<List<dynamic>> getInvoices({
    String? startDate,
    String? endDate,
    String? status,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return [];

      String url = '$baseUrl/invoices?';
      if (startDate != null) url += 'start_date=$startDate&';
      if (endDate != null) url += 'end_date=$endDate&';
      if (status != null) url += 'status=$status&';
      url = url.replaceAll(RegExp(r'[&?]$'), '');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['invoices'] ?? [];
      }
    } catch (e) {
      print("Error fetching invoices: $e");
    }
    return [];
  }

  // Download invoice as PDF
  Future<http.Response?> downloadInvoicePDF(String orderId) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/invoices/$orderId/pdf'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return response;
      }
    } catch (e) {
      print("Error downloading invoice PDF: $e");
    }
    return null;
  }

  // --- REVENUE & PROFIT/LOSS METHODS ---

  // Get revenue and profit/loss for date range
  Future<Map<String, dynamic>?> getRevenue({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final token = await _getAuthToken();
      if (token == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/revenue?start_date=$startDate&end_date=$endDate'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to get revenue data');
      }
    } catch (e) {
      print("Error fetching revenue: $e");
      rethrow;
    }
  }
}
