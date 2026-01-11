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

  // Pagination state
  int _currentPage = 1;
  int _totalCount = 0;
  bool _hasNextPage = false;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  // Sorting state
  String _sortBy = 'created_at';
  String _sortOrder = 'desc';

  // Status counts
  Map<String, int> _statusCounts = {
    'all': 0,
    'processing': 0,
    'in-transit': 0,
    'delivered': 0,
  };

  // Search state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<dynamic> _allOrders = [];

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
    _scrollController.addListener(_onScroll);
    _loadOrders();
    _loadStatusCounts();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreOrders();
    }
  }

  Future<void> _loadStatusCounts() async {
    try {
      final counts = await _pmService.getDeliveryStatusCounts();
      setState(() {
        _statusCounts = counts;
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadOrders() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await _pmService.getDeliveryQueuePaginated(
        page: 1,
        pageSize: 20,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      setState(() {
        _allOrders = response.orders;
        _orders = _filterOrdersBySearch(_allOrders);
        _currentPage = response.page;
        _totalCount = response.totalCount;
        _hasNextPage = response.hasNext;
        _loading = false;
      });

      _loadStatusCounts();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<dynamic> _filterOrdersBySearch(List<dynamic> orders) {
    if (_searchQuery.isEmpty) return orders;

    return orders.where((order) {
      final orderId = order['order_id']?.toString() ?? order['id']?.toString() ?? '';
      return orderId.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _orders = _filterOrdersBySearch(_allOrders);
    });
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _orders = _allOrders;
    });
  }

  Future<void> _loadMoreOrders() async {
    if (_isLoadingMore || !_hasNextPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await _pmService.getDeliveryQueuePaginated(
        page: _currentPage + 1,
        pageSize: 20,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        status: _selectedFilter == 'all' ? null : _selectedFilter,
      );

      setState(() {
        _allOrders.addAll(response.orders);
        _orders = _filterOrdersBySearch(_allOrders);
        _currentPage = response.page;
        _hasNextPage = response.hasNext;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
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

  String _formatDateWithTime(dynamic dateValue) {
    if (dateValue == null) return "Not set";
    try {
      DateTime date;

      if (dateValue is Map) {
        final seconds = dateValue['_seconds'] ?? dateValue['seconds'];
        if (seconds != null) {
          date = DateTime.fromMillisecondsSinceEpoch((seconds as num).toInt() * 1000).toLocal();
        } else {
          return "Invalid date";
        }
      } else if (dateValue is String) {
        if (dateValue.contains('T') || dateValue.endsWith('Z')) {
          date = DateTime.parse(dateValue).toLocal();
        } else {
          date = DateTime.parse(dateValue);
        }
      } else if (dateValue is int) {
        if (dateValue > 1000000000000) {
          date = DateTime.fromMillisecondsSinceEpoch(dateValue).toLocal();
        } else {
          date = DateTime.fromMillisecondsSinceEpoch(dateValue * 1000).toLocal();
        }
      } else {
        return "Invalid date";
      }

      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${date.day} ${monthNames[date.month - 1]} ${date.year}, "
             "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Invalid date";
    }
  }

  String? _getProductImageUrl(Map<String, dynamic> item) {
    final keys = ['product_image_url', 'imageUrl', 'image_url', 'image'];
    for (final key in keys) {
      final value = item[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Color(0xFFFFF5E6),
        iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: Color(0xFFFF7733)),
            onPressed: _loadOrders,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 1200),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Section
                  Padding(
                    padding: EdgeInsets.fromLTRB(24, 24, 24, 32),
                    child: Column(
                      children: [
                        Text(
                          "DELIVERY QUEUE",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w300,
                            letterSpacing: 4,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                        SizedBox(height: 12),
                        Container(width: 40, height: 2, color: Color(0xFFFF7733)),
                        SizedBox(height: 24),
                        // Search Bar
                        Container(
                          constraints: BoxConstraints(maxWidth: 600),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            decoration: InputDecoration(
                              hintText: 'Search by Order ID...',
                              hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                              prefixIcon: Icon(Icons.search, color: Color(0xFF6B7280), size: 20),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear, color: Color(0xFF6B7280), size: 20),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Color(0xFFFF7733), width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        // Summary Info Card
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFFE5E7EB), width: 0.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 20, color: Color(0xFF6B7280)),
                              SizedBox(width: 8),
                              Text(
                                _searchQuery.isEmpty ? 'Total Orders: ' : 'Found: ',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              Text(
                                _searchQuery.isEmpty ? '$_totalCount' : '${_orders.length}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1A1A2E),
                                ),
                              ),
                              if (_searchQuery.isNotEmpty) ...[
                                Text(
                                  ' of $_totalCount',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                              SizedBox(width: 24),
                              _buildSortDropdown(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Filter Chips
                  Container(
                    color: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildFilterChip('All Orders', 'all', _statusCounts['all'] ?? 0, Colors.grey, Icons.list_rounded),
                          SizedBox(width: 12),
                          _buildFilterChip('Processing', 'processing', _statusCounts['processing'] ?? 0, Colors.orange, Icons.hourglass_empty_rounded),
                          SizedBox(width: 12),
                          _buildFilterChip('In Transit', 'in-transit', _statusCounts['in-transit'] ?? 0, Colors.blue, Icons.local_shipping_rounded),
                          SizedBox(width: 12),
                          _buildFilterChip('Delivered', 'delivered', _statusCounts['delivered'] ?? 0, Colors.green, Icons.check_circle_rounded),
                        ],
                      ),
                    ),
                  ),
                  // Orders List
                  _loading
                      ? Container(
                          height: 400,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF7733),
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : _error != null
                          ? _buildError()
                          : _orders.isEmpty
                              ? _buildEmptyState()
                              : Column(
                                  children: [
                                    ListView.builder(
                                      shrinkWrap: true,
                                      physics: NeverScrollableScrollPhysics(),
                                      padding: EdgeInsets.all(16),
                                      itemCount: _orders.length,
                                      itemBuilder: (context, index) {
                                        return _buildOrderCard(_orders[index]);
                                      },
                                    ),
                                    if (_isLoadingMore)
                                      Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(
                                            color: Color(0xFFFF7733),
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    if (!_hasNextPage && _orders.isNotEmpty)
                                      Padding(
                                        padding: EdgeInsets.all(24),
                                        child: Text(
                                          'No more orders to load',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Color(0xFF6B7280),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: '${_sortBy}_$_sortOrder',
          icon: Icon(Icons.sort, color: Color(0xFFFF7733), size: 20),
          isDense: true,
          items: [
            DropdownMenuItem(
              value: 'created_at_desc',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_downward, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text('Newest First', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: 'created_at_asc',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_upward, size: 16, color: Colors.grey[600]),
                  SizedBox(width: 8),
                  Text('Oldest First', style: TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              final parts = value.split('_');
              setState(() {
                _sortOrder = parts.last;
                _sortBy = parts.sublist(0, parts.length - 1).join('_');
                _currentPage = 1;
                _orders = [];
              });
              _loadOrders();
            }
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String filter, int count, Color color, IconData icon) {
    final isSelected = _selectedFilter == filter;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = filter;
            _currentPage = 1;
            _orders = [];
          });
          _loadOrders();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.15) : Colors.grey[100],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : Colors.grey[300]!,
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? color : Colors.grey[600]),
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
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = order['order_id'] ?? order['id'];
    final status = order['status'] ?? 'unknown';
    final totalAmount = order['total_amount'] ?? 0;
    final items = order['items'] ?? [];
    final customerName = order['customer_name'] ?? 'Unknown Customer';
    final createdAt = order['created_at'];

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
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Color(0xFFFF7733), Color(0xFFFFA366)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.receipt_long_rounded, color: Colors.white, size: 24),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order #$orderId',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFFFF7733)),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Customer: $customerName',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey[700]),
                            ),
                            SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                SizedBox(width: 4),
                                Text(
                                  _formatDateWithTime(createdAt),
                                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [statusColor, statusColor.withOpacity(0.8)]),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: statusColor.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: Colors.white),
                      SizedBox(width: 6),
                      Text(statusLabel, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 12),
            Text('Items (${items.length}):', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            SizedBox(height: 12),
            ...items.map((item) {
              final productId = item['product_id'];
              final productName = item['product_name'] ?? 'Unknown Product';
              final quantity = item['quantity'];
              final imageUrl = _getProductImageUrl(item);

              return Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: imageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _productPlaceholder(),
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF7733)),
                                    ),
                                  );
                                },
                              ),
                            )
                          : _productPlaceholder(),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(productName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600), maxLines: 2, overflow: TextOverflow.ellipsis),
                          SizedBox(height: 4),
                          Text('ID: $productId', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Color(0xFFFF7733).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('Qty: $quantity', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFFFF7733))),
                    ),
                  ],
                ),
              );
            }).toList(),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total Amount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey[700])),
                Text('\$${totalAmount.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFF7733))),
              ],
            ),
            if (status != 'delivered') ...[
              SizedBox(height: 20),
              Row(
                children: [
                  if (status == 'processing')
                    Expanded(
                      child: _buildActionButton('Ship Order', Icons.local_shipping_rounded, Colors.blue, () => _updateOrderStatus(orderId.toString(), 'in-transit')),
                    ),
                  if (status == 'processing') SizedBox(width: 12),
                  if (status == 'in-transit')
                    Expanded(
                      child: _buildActionButton('Mark Delivered', Icons.check_circle_rounded, Colors.green, () => _updateOrderStatus(orderId.toString(), 'delivered')),
                    ),
                  if (status == 'in-transit') SizedBox(width: 12),
                  Expanded(
                    child: _buildCancelButton(() => _updateOrderStatus(orderId.toString(), 'cancelled')),
                  ),
                ],
              ),
            ] else ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 24),
                    SizedBox(width: 12),
                    Expanded(child: Text('This order has been successfully delivered', style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.w600, fontSize: 14))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.8)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCancelButton(VoidCallback onTap) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red, width: 2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
              SizedBox(width: 8),
              Text('Cancel', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _productPlaceholder() {
    return Container(
      alignment: Alignment.center,
      child: Icon(Icons.shopping_bag_outlined, size: 24, color: Colors.grey[400]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(color: Colors.green[50], shape: BoxShape.circle),
            child: Icon(Icons.check_circle_outline_rounded, size: 80, color: Colors.green[400]),
          ),
          SizedBox(height: 24),
          Text(
            _selectedFilter == 'all' ? 'No orders to display!' : 'No ${_selectedFilter} orders!',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[700]),
          ),
          SizedBox(height: 8),
          Text('All caught up!', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
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
              decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
              child: Icon(Icons.error_outline_rounded, size: 64, color: Colors.red[400]),
            ),
            SizedBox(height: 24),
            Text('Error loading orders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey[800])),
            SizedBox(height: 8),
            Text(_error ?? 'Unknown error', style: TextStyle(fontSize: 14, color: Colors.grey[600]), textAlign: TextAlign.center),
            SizedBox(height: 24),
            Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFFF7733), Color(0xFFFFA366)]),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Color(0xFFFF7733).withOpacity(0.3), blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _loadOrders,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
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
