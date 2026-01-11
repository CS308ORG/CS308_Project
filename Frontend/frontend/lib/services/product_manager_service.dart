import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DeliveryQueueResponse {
  final List<dynamic> orders;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final bool hasNext;
  final bool hasPrev;

  DeliveryQueueResponse({
    required this.orders,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
    required this.hasNext,
    required this.hasPrev,
  });

  factory DeliveryQueueResponse.fromJson(Map<String, dynamic> json) {
    final pagination = json['pagination'];
    final orders = json['orders'] ?? [];

    if (pagination != null && pagination is Map) {
      return DeliveryQueueResponse(
        orders: orders,
        page: pagination['page'] ?? 1,
        pageSize: pagination['page_size'] ?? 20,
        totalCount: pagination['total_count'] ?? orders.length,
        totalPages: pagination['total_pages'] ?? 1,
        hasNext: pagination['has_next'] ?? false,
        hasPrev: pagination['has_prev'] ?? false,
      );
    } else {
      // No pagination in response
      return DeliveryQueueResponse(
        orders: orders,
        page: 1,
        pageSize: orders.length,
        totalCount: orders.length,
        totalPages: 1,
        hasNext: false,
        hasPrev: false,
      );
    }
  }
}

class ProductManagerService {
  final String baseUrl = 'http://localhost:3000';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // =====================================================
  // Delivery Management
  // =====================================================

  Future<List<dynamic>> getDeliveryQueue() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/orders/delivery'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['orders'] ?? [];
    } else if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else {
      throw Exception('Failed to load delivery queue');
    }
  }

  // NEW: Paginated delivery queue method
  Future<DeliveryQueueResponse> getDeliveryQueuePaginated({
    int page = 1,
    int pageSize = 20,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
    String? status,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final queryParams = <String, String>{
      'page': page.toString(),
      'page_size': pageSize.toString(),
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (status != null && status != 'all') {
      queryParams['status'] = status;
    }

    final uri = Uri.parse('$baseUrl/orders/delivery').replace(queryParameters: queryParams);

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return DeliveryQueueResponse.fromJson(data);
    } else if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else {
      throw Exception('Failed to load delivery queue');
    }
  }

  // NEW: Get status counts
  Future<Map<String, int>> getDeliveryStatusCounts() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/orders/delivery/counts'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final counts = data['counts'] ?? {};
        return {
          'all': counts['all'] ?? 0,
          'processing': counts['processing'] ?? 0,
          'in-transit': counts['in-transit'] ?? 0,
          'delivered': counts['delivered'] ?? 0,
        };
      } else {
        throw Exception('Failed to load counts');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getDeliveries() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/deliveries'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['deliveries'] ?? [];
    } else if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else {
      throw Exception('Failed to load deliveries');
    }
  }

  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('$baseUrl/orders/$orderId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'status': newStatus}),
    );

    if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to update order status');
    }
  }

  // =====================================================
  // Product Management (12.1)
  // =====================================================

  Future<List<dynamic>> getProducts() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.get(
      Uri.parse('$baseUrl/products/manage'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['products'] ?? [];
    } else if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else {
      throw Exception('Failed to load products');
    }
  }

  Future<Map<String, dynamic>> addProduct(Map<String, dynamic> productData) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/products'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(productData),
    );

    if (response.statusCode == 201) {
      return json.decode(response.body);
    } else if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to add product');
    }
  }

  Future<Map<String, dynamic>> updateProduct(String productId, Map<String, dynamic> updates) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.put(
      Uri.parse('$baseUrl/products/$productId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(updates),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to update product');
    }
  }

  Future<void> deleteProduct(String productId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$baseUrl/products/$productId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to delete product');
    }
  }

  Future<Map<String, dynamic>> uploadProductImage({
    required String fileName,
    required String base64Data,
    required String mimeType,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/upload/product-image'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'fileName': fileName,
        'base64Data': base64Data,
        'mimeType': mimeType,
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to upload image');
    }
  }

  // =====================================================
  // Stock Management (12.1)
  // =====================================================

  Future<Map<String, dynamic>> updateStock(String productId, {int? absoluteValue, int? adjustment}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    Map<String, dynamic> body = {};
    if (absoluteValue != null) {
      body['quantity_in_stock'] = absoluteValue;
    } else if (adjustment != null) {
      body['adjustment'] = adjustment;
    }

    final response = await http.put(
      Uri.parse('$baseUrl/products/$productId/stock'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode(body),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to update stock');
    }
  }

  // =====================================================
  // Category Management (12.1)
  // =====================================================

  Future<List<String>> getCategories({bool includeEmpty = false}) async {
    String url = '$baseUrl/categories';
    if (includeEmpty) {
      url += '?include_empty=true';
    }
    
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<String>.from(data['categories'] ?? []);
    } else {
      throw Exception('Failed to load categories');
    }
  }

  // Get all categories for management (includes default + custom)
  Future<List<String>> getAllCategoriesForManagement() async {
    // Get categories from backend (includes empty ones)
    final backendCategories = await getCategories(includeEmpty: true);
    
    // Default categories that should always be available for management
    final defaultCategories = [
      'Electronics',
      'Wear',
      'Home Appliances',
      'Computers',
      'Audio',
      'Phones',
      'Accessories',
      'Gaming',
      'Sports',
      'Books',
    ];
    
    // Combine and deduplicate
    final allCategories = <String>{...defaultCategories, ...backendCategories};
    return allCategories.toList()..sort();
  }

  Future<void> addCategory(String name, {String? description}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'name': name,
        'description': description ?? '',
      }),
    );

    if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else if (response.statusCode != 201) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to add category');
    }
  }

  Future<void> deleteCategory(String name) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final response = await http.delete(
      Uri.parse('$baseUrl/categories/${Uri.encodeComponent(name)}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 403) {
      throw Exception('Access denied - Product Manager role required');
    } else if (response.statusCode != 200) {
      final error = json.decode(response.body);
      throw Exception(error['error'] ?? 'Failed to delete category');
    }
  }

  // =====================================================
  // Invoice Management (12.2)
  // =====================================================

  Future<List<dynamic>> getInvoices({String? startDate, String? endDate}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    String url = '$baseUrl/invoices';
    List<String> queryParams = [];
    if (startDate != null) queryParams.add('start_date=$startDate');
    if (endDate != null) queryParams.add('end_date=$endDate');
    if (queryParams.isNotEmpty) {
      url += '?${queryParams.join('&')}';
    }

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['invoices'] ?? [];
    } else if (response.statusCode == 403) {
      throw Exception('Access denied');
    } else {
      throw Exception('Failed to load invoices');
    }
  }
}