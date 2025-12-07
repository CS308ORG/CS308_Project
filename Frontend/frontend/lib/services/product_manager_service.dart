import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProductManagerService {
  final String baseUrl = 'http://localhost:3000';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

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
}