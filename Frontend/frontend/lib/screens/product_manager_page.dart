import 'package:flutter/material.dart';
import '../services/product_manager_service.dart';

class ProductManagerPage extends StatefulWidget {
  @override
  _ProductManagerPageState createState() => _ProductManagerPageState();
}

class _ProductManagerPageState extends State<ProductManagerPage> with SingleTickerProviderStateMixin {
  final ProductManagerService _pmService = ProductManagerService();
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;
  String _selectedFilter = 'all';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _loadOrders();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Order status updated to $newStatus'),
            ],
          ),
          backgroundColor: Color(0xFFFF7733),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      _loadOrders();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Failed to update order: $e'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
        elevation: 0,
        backgroundColor: Color(0xFFFF7733),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_shipping_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Delivery Queue',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(Icons.refresh_rounded),
              onPressed: _loadOrders,
              tooltip: 'Refresh',
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            // Status Filter Chips
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip(
                      'All Orders',
                      'all',
                      _orders.length,
                      Colors.grey,
                      Icons.list_rounded,
                    ),
                    SizedBox(width: 12),
                    _buildFilterChip(
                      'Processing',
                      'processing',
                      processingCount,
                      Colors.orange,
                      Icons.hourglass_empty_rounded,
                    ),
                    SizedBox(width: 12),
                    _buildFilterChip(
                      'In Transit',
                      'in-transit',
                      inTransitCount,
                      Colors.blue,
                      Icons.local_shipping_rounded,
                    ),
                    SizedBox(width: 12),
                    _buildFilterChip(
                      'Delivered',
                      'delivered',
                      deliveredCount,
                      Colors.green,
                      Icons.check_circle_rounded,
                    ),
                  ],
                ),
              ),
            ),

            // Orders List
            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF7733),
                        strokeWidth: 3,
                      ),
                    )
                  : _error != null
                      ? _buildError()
                      : _filteredOrders.isEmpty
                          ? _buildEmptyState()
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
      ),
    );
  }

  Widget _buildFilterChip(String label, String filter, int count, Color color, IconData icon) {
    final isSelected = _selectedFilter == filter;
    return Container(
      margin: EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedFilter = filter;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withOpacity(0.15)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? color : Colors.grey[300]!,
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? color : Colors.grey[600],
                ),
                SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? color : Colors.grey[700],
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isSelected ? color : Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['order_id'] ?? order['id'];
    final status = order['status'] ?? 'unknown';
    final totalAmount = order['total_amount'] ?? 0;
    final items = order['items'] ?? [];
    final userId = order['user_id'];
    final customerName = order['customer_name'] ?? 'Unknown Customer';

    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status) {
      case 'processing':
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty_rounded;
        statusLabel = 'Processing';
        break;
      case 'in-transit':
        statusColor = Colors.blue;
        statusIcon = Icons.local_shipping_rounded;
        statusLabel = 'In Transit';
        break;
      case 'delivered':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_rounded;
        statusLabel = 'Delivered';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline_rounded;
        statusLabel = 'Unknown';
    }

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 8),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFFFF7733),
                            Color(0xFFFFA366),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #$orderId',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF7733),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Customer ID: $userId',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Name: $customerName',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor,
                        statusColor.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 18, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 16),

            // Items Section
            Text(
              'Items (${items.length}):',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 12),
            ...items.map((item) {
              final productId = item['product_id'];
              final productName = item['product_name'] ?? 'Unknown Product';
              final quantity = item['quantity'];
              
              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 20,
                      color: Color(0xFFFF7733),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Product ID: $productId',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Name: $productName',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color(0xFFFF7733).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Qty: $quantity',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7733),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),

            // Total Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Amount',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                Text(
                  '\$${totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7733),
                  ),
                ),
              ],
            ),

            // Action Buttons
            if (status != 'delivered') ...[
              SizedBox(height: 20),
              Row(
                children: [
                  if (status == 'processing')
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue, Colors.blue[700]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blue.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                _updateOrderStatus(orderId.toString(), 'in-transit'),
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Ship Order',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (status == 'processing') SizedBox(width: 12),
                  if (status == 'in-transit')
                    Expanded(
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green, Colors.green[700]!],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withOpacity(0.3),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () =>
                                _updateOrderStatus(orderId.toString(), 'delivered'),
                            borderRadius: BorderRadius.circular(12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Mark Delivered',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (status == 'in-transit') SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red, width: 2),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () =>
                              _updateOrderStatus(orderId.toString(), 'cancelled'),
                          borderRadius: BorderRadius.circular(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.green.withOpacity(0.1),
                      Colors.green.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'This order has been successfully delivered',
                        style: TextStyle(
                          color: Colors.green[800],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.green[50],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline_rounded,
              size: 80,
              color: Colors.green[400],
            ),
          ),
          SizedBox(height: 24),
          Text(
            _selectedFilter == 'all'
                ? 'No orders to display!'
                : 'No ${_selectedFilter} orders!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'All caught up!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            SizedBox(height: 24),
            Text(
              'Error loading orders',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24),
            Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF7733),
                    Color(0xFFFFA366),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF7733).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loadOrders,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Retry',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
