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
  String _selectedFilter = 'all'; // all, processing, in-transit, delivered

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

  List<dynamic> get _filteredOrders {
    if (_selectedFilter == 'all') return _orders;
    return _orders.where((order) => order['status'] == _selectedFilter).toList();
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

  int _getStatusCount(String status) {
    return _orders.where((order) => order['status'] == status).length;
  }

  @override
  Widget build(BuildContext context) {
    final processingCount = _getStatusCount('processing');
    final inTransitCount = _getStatusCount('in-transit');
    final deliveredCount = _getStatusCount('delivered');

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
      body: Column(
        children: [
          // Status Filter Chips
          Container(
            color: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip(
                    'All Orders',
                    'all',
                    _orders.length,
                    Colors.grey,
                  ),
                  SizedBox(width: 8),
                  _buildFilterChip(
                    'Processing',
                    'processing',
                    processingCount,
                    Colors.orange,
                  ),
                  SizedBox(width: 8),
                  _buildFilterChip(
                    'In Transit',
                    'in-transit',
                    inTransitCount,
                    Colors.blue,
                  ),
                  SizedBox(width: 8),
                  _buildFilterChip(
                    'Delivered',
                    'delivered',
                    deliveredCount,
                    Colors.green,
                  ),
                ],
              ),
            ),
          ),

          // Orders List
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF7733)),
                  )
                : _error != null
                    ? _buildError()
                    : _filteredOrders.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  size: 64,
                                  color: Colors.green,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  _selectedFilter == 'all'
                                      ? 'No orders to display!'
                                      : 'No ${_selectedFilter} orders!',
                                  style: TextStyle(fontSize: 18),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: EdgeInsets.all(16),
                            itemCount: _filteredOrders.length,
                            itemBuilder: (context, index) {
                              return _buildOrderCard(_filteredOrders[index]);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String filter, int count, Color color) {
    final isSelected = _selectedFilter == filter;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          SizedBox(width: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : color.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? color : Colors.black87,
              ),
            ),
          ),
        ],
      ),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      backgroundColor: Colors.white,
      side: BorderSide(color: isSelected ? color : Colors.grey.shade300),
      onSelected: (selected) {
        setState(() {
          _selectedFilter = filter;
        });
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['order_id'] ?? order['id'];
    final status = order['status'] ?? 'unknown';
    final totalAmount = order['total_amount'] ?? 0;
    final items = order['items'] ?? [];
    final userId = order['user_id'];

    Color statusColor;
    IconData statusIcon;
    
    switch (status) {
      case 'processing':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        break;
      case 'in-transit':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping;
        break;
      case 'delivered':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
    }

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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      SizedBox(width: 6),
                      Text(
                        status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
            
            // Only show action buttons if not delivered
            if (status != 'delivered') ...[
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
            ] else ...[
              // Delivered orders show completion info
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This order has been successfully delivered',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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