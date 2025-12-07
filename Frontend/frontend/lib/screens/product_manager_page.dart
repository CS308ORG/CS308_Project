import 'package:flutter/material.dart';
import '../services/product_manager_service.dart';

class ProductManagerPage extends StatefulWidget {
  @override
  _ProductManagerPageState createState() => _ProductManagerPageState();
}

class _ProductManagerPageState extends State<ProductManagerPage> {
  final ProductManagerService _pmService = ProductManagerService();
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final orders = await _pmService.getDeliveryQueue();
      setState(() {
        _orders = orders;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await _pmService.updateOrderStatus(orderId, newStatus);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to $newStatus'),
          backgroundColor: Color(0xFFFF7733),
        ),
      );
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        backgroundColor: Color(0xFFFF7733),
        title: Text('Product Manager - Delivery Queue'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7733)),
            )
          : _error != null
              ? _buildError()
              : _orders.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              size: 64, color: Colors.green),
                          SizedBox(height: 16),
                          Text(
                            'No pending deliveries!',
                            style: TextStyle(fontSize: 18),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: _orders.length,
                      itemBuilder: (context, index) {
                        return _buildOrderCard(_orders[index]);
                      },
                    ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['order_id'] ?? order['id'];
    final status = order['status'] ?? 'unknown';
    final totalAmount = order['total_amount'] ?? 0;
    final items = order['items'] ?? [];
    final userId = order['user_id'];

    Color statusColor = status == 'processing' ? Colors.orange : Colors.blue;

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #$orderId',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7733),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Customer ID: $userId',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            Text(
              'Items (${items.length}):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            ...items.map((item) {
              return Padding(
                padding: EdgeInsets.only(left: 16, bottom: 4),
                child: Text(
                  '• Product ID: ${item['product_id']} - Qty: ${item['quantity']}',
                  style: TextStyle(color: Colors.grey[800]),
                ),
              );
            }).toList(),
            SizedBox(height: 12),
            Text(
              'Total: \$${totalAmount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7733),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (status == 'processing')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _updateOrderStatus(orderId.toString(), 'in-transit'),
                      icon: Icon(Icons.local_shipping),
                      label: Text('Ship Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                if (status == 'processing') SizedBox(width: 8),
                if (status == 'in-transit')
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          _updateOrderStatus(orderId.toString(), 'delivered'),
                      icon: Icon(Icons.check_circle),
                      label: Text('Mark Delivered'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _updateOrderStatus(orderId.toString(), 'cancelled'),
                    icon: Icon(Icons.cancel),
                    label: Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Error loading orders'),
          SizedBox(height: 8),
          Text(_error ?? ''),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF7733),
            ),
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
}