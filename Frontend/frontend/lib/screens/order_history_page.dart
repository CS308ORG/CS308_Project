import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import 'home_screen.dart'; // For StoreLayout

class OrderHistoryPage extends StatefulWidget {
  @override
  _OrderHistoryPageState createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        // Backend instructions: implement GET /users/:uid/orders
        // For demo, we simulate a response if backend is empty
        List<dynamic> fetchedOrders = await _apiService.getUserOrders(user.uid);

        if (fetchedOrders.isEmpty) {
          // SIMULATED DATA FOR DEMO (Feature 4.5)
          fetchedOrders = [
            {
              "order_id": 1001,
              "status": "Order created",
              "delivery_address": "Sabanci Univ, Istanbul",
              "contact": user.email,
              "total": 137.0,
              "items": [
                {
                  "sku": "SKU783",
                  "name": "Wireless headphones",
                  "qty": 1,
                  "price": 88.0,
                },
                {
                  "sku": "SKU456",
                  "name": "Bluetooth Speakers",
                  "qty": 1,
                  "price": 49.0,
                },
              ],
            },
          ];
        }

        if (mounted) {
          setState(() {
            _orders = fetchedOrders;
            _loading = false;
          });
        }
      } catch (e) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Feature 4.3: Use StoreLayout for consistent header/nav
    return StoreLayout(
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)))
          : SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Order History",
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF7733),
                          ),
                        ),
                        SizedBox(height: 24),
                        ..._orders
                            .map((order) => _buildOrderCard(order))
                            .toList(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    // Feature 4.5: Detailed Order Card
    return Container(
      margin: EdgeInsets.only(bottom: 24),
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFFF7733).withOpacity(0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Current status of the delivery: ${order['status']}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
              fontSize: 16,
            ),
          ),
          Divider(),
          SizedBox(height: 8),
          _row("Customer ID:", FirebaseAuth.instance.currentUser?.uid ?? "N/A"),
          _row("Delivery Address:", order['delivery_address'] ?? "N/A"),
          _row("Customer Contact:", order['contact'] ?? "N/A"),
          SizedBox(height: 16),
          Text(
            "Ordered Products:",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...(order['items'] as List)
              .map(
                (item) => Padding(
                  padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("${item['qty']}x (${item['sku']}) ${item['name']}"),
                      Text("${item['price']}\$"),
                    ],
                  ),
                ),
              )
              .toList(),
          Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Order Total:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                "${order['total']}\$",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFFFF7733),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
