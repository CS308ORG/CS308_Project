import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'product_detail.dart';

class OrderHistoryPage extends StatefulWidget {
  final int? highlightOrderId;

  const OrderHistoryPage({Key? key, this.highlightOrderId}) : super(key: key);

  @override
  _OrderHistoryPageState createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  bool _loading = true;
  bool _isUsingMockData = false;
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _orderKeys = {};

  // Design constants
  static const Color _primaryText = Color(0xFF1A1A2E);
  static const Color _secondaryText = Color(0xFF6B7280);
  static const Color _accentColor = Color(0xFFFF7733);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _cardBackground = Colors.white;
  static const Color _pageBackground = Color(0xFFFFF5E6); // Match site theme

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToHighlightedOrder() {
    if (widget.highlightOrderId != null) {
      final key = _orderKeys[widget.highlightOrderId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _fetchOrders() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null && AuthService().isLoggedIn) {
      final currentUser = AuthService().currentUser;
      uid = currentUser?['id']?.toString() ?? currentUser?['user_id']?.toString();
    }

    if (uid != null) {
      try {
        List<dynamic> fetchedOrders = await _apiService.getUserOrders(uid);

        if (fetchedOrders.isEmpty) {
          setState(() {
            _isUsingMockData = true;
          });
          fetchedOrders = [
            {
              "order_id": 1001,
              "status": "processing",
              "date": "2023-11-01T10:00:00",
              "delivery_address": "Sabanci Univ, Istanbul",
              "total_amount": 1899.70,
              "items": [
                {"product_id": 1, "name": "Wireless Headphones", "quantity": 1, "unit_price": 1499.90, "imageUrl": null},
                {"product_id": 4, "name": "Cotton T-Shirt L", "quantity": 2, "unit_price": 199.90, "imageUrl": null},
              ],
            },
            {
              "order_id": 1009,
              "status": "in_transit",
              "date": "2023-10-20T09:15:00",
              "delivery_address": "Kocaeli, TR",
              "total_amount": 28158.00,
              "items": [
                {"product_id": 3, "name": "Laptop Pro 14", "quantity": 1, "unit_price": 27999.00, "imageUrl": null},
              ],
            },
          ];
        } else {
          setState(() {
            _isUsingMockData = false;
          });
        }

        fetchedOrders.sort((a, b) {
          DateTime? dateA;
          DateTime? dateB;

          try {
            if (a['created_at'] != null) {
              dateA = DateTime.tryParse(a['created_at'].toString());
            }
            if (b['created_at'] != null) {
              dateB = DateTime.tryParse(b['created_at'].toString());
            }
          } catch (e) {}

          if (dateA == null && a['date'] != null) {
            dateA = DateTime.tryParse(a['date'].toString());
          }
          if (dateB == null && b['date'] != null) {
            dateB = DateTime.tryParse(b['date'].toString());
          }

          if (dateA != null && dateB != null) {
            return dateB.millisecondsSinceEpoch - dateA.millisecondsSinceEpoch;
          } else if (dateA != null) {
            return -1;
          } else if (dateB != null) {
            return 1;
          }
          return 0;
        });

        if (mounted) {
          setState(() {
            _orders = fetchedOrders;
            _loading = false;
          });
          // Scroll to highlighted order after build
          if (widget.highlightOrderId != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToHighlightedOrder();
            });
          }
        }
      } catch (e) {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return "Unknown";
    switch (status.toLowerCase()) {
      case 'in_transit': return 'In Transit';
      case 'delivered': return 'Delivered';
      case 'processing': return 'Processing';
      case 'cancelled': return 'Cancelled';
      default:
        if (status.length > 1) return status[0].toUpperCase() + status.substring(1);
        return status.toUpperCase();
    }
  }

  String? getProductImageUrl(Map<String, dynamic> product) {
    final keys = ['imageUrl', 'image_url', 'image', 'thumbnailUrl', 'thumbnail_url'];
    for (final key in keys) {
      if (product[key] != null && product[key].toString().isNotEmpty) {
        return product[key].toString();
      }
    }
    return null;
  }

  String _formatDateWithTime(dynamic dateValue) {
    if (dateValue == null) return "Not set";
    try {
      String dateStr = dateValue.toString();
      DateTime date;
      if (dateStr.endsWith('Z') || dateStr.contains('+00:00')) {
        date = DateTime.parse(dateStr.replaceAll('+00:00', 'Z')).toLocal();
      } else {
        final parsed = DateTime.parse(dateStr);
        date = parsed.isUtc ? parsed.toLocal() : parsed;
      }
      final monthNames = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return "${date.day} ${monthNames[date.month - 1]} ${date.year}, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return "Invalid date";
    }
  }

  @override
  Widget build(BuildContext context) {
    String userId = 'Unknown';
    String userEmail = 'No Email';

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      userId = firebaseUser.uid;
      userEmail = firebaseUser.email ?? 'No Email';
    } else if (AuthService().isLoggedIn) {
      final customUser = AuthService().currentUser;
      userId = customUser?['id']?.toString() ?? customUser?['user_id']?.toString() ?? 'N/A';
      userEmail = customUser?['email'] ?? 'N/A';
    }

    return StoreLayout(
      body: Container(
        color: _pageBackground,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _accentColor, strokeWidth: 2))
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 80),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Section
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
                          child: Column(
                            children: [
                              Text(
                                "MY ORDERS",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 4,
                                  color: _primaryText,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(width: 40, height: 2, color: _accentColor),
                              const SizedBox(height: 32),
                              // User Info Card
                              Container(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
                                decoration: BoxDecoration(
                                  color: _cardBackground,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _borderColor, width: 0.5),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildUserInfoItem("CUSTOMER ID", userId),
                                    Container(height: 40, width: 1, color: _borderColor, margin: const EdgeInsets.symmetric(horizontal: 32)),
                                    _buildUserInfoItem("EMAIL", userEmail),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (_isUsingMockData)
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              border: Border.all(color: Colors.amber.shade300, width: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "No orders found. Displaying sample data.",
                                    style: TextStyle(color: Colors.amber.shade800, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        if (_orders.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(48),
                            child: Column(
                              children: [
                                Icon(Icons.shopping_bag_outlined, size: 64, color: _secondaryText.withOpacity(0.3)),
                                const SizedBox(height: 16),
                                Text(
                                  "No orders yet",
                                  style: TextStyle(fontSize: 16, color: _secondaryText, fontWeight: FontWeight.w300),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _orders.length,
                            itemBuilder: (context, index) {
                              final order = _orders[index];
                              final orderIdInt = order['order_id'] ?? order['id'];
                              // Create key for scrolling to this order
                              if (orderIdInt != null) {
                                _orderKeys[orderIdInt] ??= GlobalKey();
                              }
                              return _buildOrderCard(order, key: _orderKeys[orderIdInt]);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildUserInfoItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _secondaryText,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _primaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, {GlobalKey? key}) {
    final items = (order['items'] as List<dynamic>?) ?? [];
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final statusRaw = order['status'] as String?;
    final statusFormatted = _formatStatus(statusRaw);
    final dateValue = order['created_at'] ?? order['date'];
    final dateFormatted = _formatDateWithTime(dateValue);
    final address = order['delivery_address'] ?? 'N/A';
    final orderId = order['order_id']?.toString() ?? order['id']?.toString() ?? 'N/A';
    final orderIdInt = order['order_id'] ?? order['id'];
    final isHighlighted = widget.highlightOrderId != null && orderIdInt == widget.highlightOrderId;

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      decoration: BoxDecoration(
        color: isHighlighted ? Color(0xFFFFF0E0) : _cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: isHighlighted
            ? Border.all(color: _accentColor, width: 2)
            : Border(left: BorderSide(color: _accentColor, width: 3)),
        boxShadow: [
          BoxShadow(
            color: isHighlighted ? _accentColor.withOpacity(0.2) : Colors.black.withOpacity(0.04),
            blurRadius: isHighlighted ? 12 : 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #$orderId',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _primaryText, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(dateFormatted, style: TextStyle(fontSize: 12, color: _secondaryText)),
                  ],
                ),
                _buildStatusBadge(statusRaw, statusFormatted),
              ],
            ),
            const SizedBox(height: 20),

            // Delivery Address
            Row(
              children: [
                Icon(Icons.location_on_outlined, color: _secondaryText, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(address, style: TextStyle(color: _secondaryText, fontSize: 13)),
                ),
              ],
            ),

            const SizedBox(height: 20),
            Container(height: 1, color: _borderColor),
            const SizedBox(height: 20),

            // Products Section
            Text(
              "ITEMS",
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _secondaryText, letterSpacing: 1.5),
            ),
            const SizedBox(height: 12),
            ...items.map((item) => _buildProductItem(item, order, statusRaw)).toList(),

            const SizedBox(height: 16),
            Container(height: 1, color: _borderColor),
            const SizedBox(height: 16),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Total", style: TextStyle(fontSize: 14, color: _secondaryText)),
                Text(
                  "${totalAmount.toStringAsFixed(2)} TL",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _primaryText),
                ),
              ],
            ),

            // Cancel Button
            if (statusRaw?.toLowerCase() == 'processing') ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _cancelOrder(order),
                  icon: Icon(Icons.close, size: 18, color: Colors.red.shade400),
                  label: Text('Cancel Order', style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.red.shade200),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status, String formatted) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        formatted,
        style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 12),
      ),
    );
  }

  Widget _buildProductItem(Map<String, dynamic> item, Map<String, dynamic> order, String? orderStatus) {
    final qty = item['quantity'] ?? 1;
    final pid = item['product_id'] ?? item['sku'] ?? '-';
    final name = item['name'] ?? 'Unknown Product';
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = getProductImageUrl(item);

    return InkWell(
      onTap: () => _navigateToProduct(item, pid, name),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _pageBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _borderColor),
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _productPlaceholder()),
                    )
                  : _productPlaceholder(),
            ),
            const SizedBox(width: 16),
            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: TextStyle(fontSize: 14, color: _primaryText, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text("Qty: $qty  •  ${unitPrice.toStringAsFixed(2)} TL each", style: TextStyle(fontSize: 12, color: _secondaryText)),
                  // Refund status or button
                  if (orderStatus == 'delivered') ...[
                    const SizedBox(height: 8),
                    if (item['refund_status'] != null)
                      _buildRefundStatusChip(item['refund_status'])
                    else
                      GestureDetector(
                        onTap: () => _showRefundDialog(context, order, item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            border: Border.all(color: _accentColor.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "Request Refund",
                            style: TextStyle(fontSize: 11, color: _accentColor, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            Text(
              "${(unitPrice * qty).toStringAsFixed(2)} TL",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _primaryText),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefundStatusChip(String status) {
    final isApproved = status == 'refunded';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isApproved ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isApproved ? Colors.green.shade200 : Colors.red.shade200),
      ),
      child: Text(
        isApproved ? "Refunded" : "Refund Declined",
        style: TextStyle(fontSize: 11, color: isApproved ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _productPlaceholder() {
    return Center(child: Icon(Icons.image_outlined, size: 24, color: _secondaryText.withOpacity(0.3)));
  }

  Future<void> _navigateToProduct(Map<String, dynamic> item, dynamic pid, String name) async {
    try {
      final products = await _apiService.getProducts();
      final product = products.firstWhere(
        (p) => (p['product_id'] ?? p['id']).toString() == pid.toString(),
        orElse: () => {'product_id': pid, 'id': pid, 'name': name, ...item},
      );

      bool? wishlistStatus;
      if (AuthService().isLoggedIn) {
        try {
          String? uid = FirebaseAuth.instance.currentUser?.uid;
          if (uid == null) {
            final currentUser = AuthService().currentUser;
            uid = currentUser?['id']?.toString() ?? currentUser?['user_id']?.toString();
          }
          if (uid != null) {
            final wishlist = await _apiService.getWishlist(uid);
            final productId = (product['id'] ?? product['product_id']).toString();
            wishlistStatus = wishlist.any((p) => (p['id'] ?? p['product_id']).toString() == productId);
          }
        } catch (e) {}
      }

      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProductDetail(product: product, initialWishlistStatus: wishlistStatus)),
      );
    } catch (e) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProductDetail(product: {'product_id': pid, 'id': pid, 'name': name, ...item})),
      );
    }
  }

  Future<void> _cancelOrder(Map<String, dynamic> order) async {
    final orderId = order['order_id']?.toString() ?? order['id']?.toString();
    if (orderId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Cancel Order', style: TextStyle(color: _primaryText, fontWeight: FontWeight.w500)),
        content: Text('Are you sure you want to cancel this order?', style: TextStyle(color: _secondaryText)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('No', style: TextStyle(color: _secondaryText))),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Yes, Cancel', style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

    try {
      final success = await _apiService.cancelOrder(orderId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Order cancelled successfully' : 'Failed to cancel order'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        if (success) _fetchOrders();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'delivered': return const Color(0xFF22C55E);
      case 'processing': return const Color(0xFF3B82F6);
      case 'in_transit': return const Color(0xFFF59E0B);
      case 'cancelled': return const Color(0xFFEF4444);
      default: return _secondaryText;
    }
  }

  void _showRefundDialog(BuildContext context, Map<String, dynamic> order, Map<String, dynamic> item) {
    final TextEditingController reasonController = TextEditingController();
    final productName = item['name'] ?? 'Product';
    final productId = item['product_id'] ?? item['id'];
    final orderId = order['order_id'] ?? order['id'];
    final unitPrice = (item['unit_price'] as num?)?.toDouble() ?? 0.0;
    final quantity = item['quantity'] ?? 1;
    final totalPrice = unitPrice * quantity;

    DateTime? purchaseDate;
    if (order['created_at'] != null) {
      purchaseDate = DateTime.tryParse(order['created_at'].toString());
    }
    if (purchaseDate == null && order['date'] != null) {
      purchaseDate = DateTime.tryParse(order['date']);
    }

    bool isWithin30Days = true;
    int daysSincePurchase = 0;
    if (purchaseDate != null) {
      daysSincePurchase = DateTime.now().difference(purchaseDate).inDays;
      isWithin30Days = daysSincePurchase <= 30;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 480),
          padding: const EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: _accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.assignment_return_outlined, color: _accentColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Request Refund', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _primaryText)),
                          Text('Order #$orderId', style: TextStyle(fontSize: 13, color: _secondaryText)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: _secondaryText),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Product Info
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _pageBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildRefundInfoRow('Product', productName),
                      _buildRefundInfoRow('Quantity', quantity.toString()),
                      _buildRefundInfoRow('Unit Price', '${unitPrice.toStringAsFixed(2)} TL'),
                      _buildRefundInfoRow('Total Refund', '${totalPrice.toStringAsFixed(2)} TL', isHighlighted: true),
                      if (purchaseDate != null)
                        _buildRefundInfoRow('Days Since Purchase', '$daysSincePurchase days'),
                    ],
                  ),
                ),

                if (!isWithin30Days) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'More than 30 days since purchase. Refund may not be eligible.',
                            style: TextStyle(color: Colors.amber.shade800, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                Text('Reason (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _secondaryText)),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Please provide a reason for your refund request...',
                    hintStyle: TextStyle(color: _secondaryText.withOpacity(0.5), fontSize: 14),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _accentColor)),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 28),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: _borderColor),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Cancel', style: TextStyle(color: _secondaryText)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await _submitRefundRequest(orderId, productId, reasonController.text);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: const Text('Submit Request', style: TextStyle(fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefundInfoRow(String label, String value, {bool isHighlighted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: _secondaryText)),
          Text(
            value,
            style: TextStyle(
              fontSize: isHighlighted ? 16 : 14,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
              color: isHighlighted ? _accentColor : _primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRefundRequest(dynamic orderId, dynamic productId, String reason) async {
    try {
      final result = await _apiService.requestRefund(orderId.toString(), productId, reason);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result != null ? 'Refund request submitted successfully' : 'Failed to submit refund request'),
            backgroundColor: result != null ? Colors.green : Colors.red,
          ),
        );
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
