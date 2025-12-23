import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'product_detail.dart';

class OrderHistoryPage extends StatefulWidget {
  @override
  _OrderHistoryPageState createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _orders = [];
  bool _loading = true;
  bool _isUsingMockData = false; // Flag for Mock Data

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null && AuthService().isLoggedIn) {
      final currentUser = AuthService().currentUser;
      uid =
          currentUser?['id']?.toString() ?? currentUser?['user_id']?.toString();
    }

    if (uid != null) {
      try {
        List<dynamic> fetchedOrders = await _apiService.getUserOrders(uid);

        if (fetchedOrders.isEmpty) {
          // --- MOCK DATA FALLBACK ---
          setState(() {
            _isUsingMockData = true; // Enable Flag
          });
          fetchedOrders = [
            {
              "order_id": 1001,
              "status": "processing",
              "date": "2023-11-01T10:00:00",
              "delivery_address": "Sabanci Univ, Istanbul",
              "total_amount": 1899.70,
              "items": [
                {
                  "product_id": 1,
                  "name": "Wireless Headphones",
                  "quantity": 1,
                  "unit_price": 1499.90,
                  "imageUrl": null,
                },
                {
                  "product_id": 4,
                  "name": "Cotton T-Shirt L",
                  "quantity": 2,
                  "unit_price": 199.90,
                  "imageUrl": null,
                },
              ],
            },
            {
              "order_id": 1009,
              "status": "in_transit",
              "date": "2023-10-20T09:15:00",
              "delivery_address": "Kocaeli, TR",
              "total_amount": 28158.00,
              "items": [
                {
                  "product_id": 3,
                  "name": "Laptop Pro 14",
                  "quantity": 1,
                  "unit_price": 27999.00,
                  "imageUrl": null,
                },
              ],
            },
          ];
        } else {
          setState(() {
            _isUsingMockData = false; // Real data found
          });
        }

        // --- UPDATED SORTING LOGIC ---
        // 1. Date (Newest to Oldest)
        // 2. Price (Highest to Lowest)
        fetchedOrders.sort((a, b) {
          final dateAStr = a['date'] as String?;
          final dateBStr = b['date'] as String?;
          final priceA = (a['total_amount'] as num?)?.toDouble() ?? 0.0;
          final priceB = (b['total_amount'] as num?)?.toDouble() ?? 0.0;

          // Date check
          if (dateAStr != null && dateBStr != null) {
            final dateA = DateTime.tryParse(dateAStr);
            final dateB = DateTime.tryParse(dateBStr);
            if (dateA != null && dateB != null) {
              int dateComparison = dateB.compareTo(
                dateA,
              ); // B vs A = Descending
              if (dateComparison != 0) return dateComparison;
            }
          } else if (dateAStr != null) {
            return -1; // A has date, A comes first
          } else if (dateBStr != null) {
            return 1; // B has date, B comes first
          }

          // Price check (if dates equal or missing)
          return priceB.compareTo(priceA); // B vs A = Descending
        });

        if (mounted) {
          setState(() {
            _orders = fetchedOrders;
            _loading = false;
          });
        }
      } catch (e) {
        print("Error fetching orders: $e");
        if (mounted) setState(() => _loading = false);
      }
    } else {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatStatus(String? status) {
    if (status == null) return "Unknown";
    switch (status.toLowerCase()) {
      case 'in_transit':
        return 'In Transit';
      case 'delivered':
        return 'Delivered';
      case 'processing':
        return 'Processing';
      case 'cancelled':
        return 'Cancelled';
      default:
        if (status.length > 1)
          return status[0].toUpperCase() + status.substring(1);
        return status.toUpperCase();
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "-";
    try {
      final date = DateTime.parse(dateStr);
      return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    } catch (e) {
      return "-";
    }
  }

  @override
  Widget build(BuildContext context) {
    String userId = 'Unknown ID';
    String userEmail = 'No Email';

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      userId = firebaseUser.uid;
      userEmail = firebaseUser.email ?? 'No Email';
    } else if (AuthService().isLoggedIn) {
      final customUser = AuthService().currentUser;
      userId =
          customUser?['id']?.toString() ??
          customUser?['user_id']?.toString() ??
          'N/A';
      userEmail = customUser?['email'] ?? 'N/A';
    }

    return StoreLayout(
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7733)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 60),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 32,
                          horizontal: 24,
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "My Orders",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 1.2,
                                color: Color(0xFFFF7733),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildUserInfoItem("Customer ID", userId),
                                  Container(
                                    height: 40,
                                    width: 1,
                                    color: Colors.grey.shade300,
                                  ),
                                  _buildUserInfoItem("Contact", userEmail),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // --- ATTENTION LABEL ---
                      if (_isUsingMockData)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            border: Border.all(color: Colors.red),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            "ATTENTION: Could not found any orders for this user. Following is mock-data",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      if (_orders.isEmpty)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text(
                              "You have no orders yet.",
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) {
                            return _buildOrderCard(_orders[index]);
                          },
                        ),
                    ],
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
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade500,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final items = (order['items'] as List<dynamic>?) ?? [];
    final totalAmount = (order['total_amount'] as num?)?.toDouble() ?? 0.0;
    final statusRaw = order['status'] as String?;
    final statusFormatted = _formatStatus(statusRaw);
    final dateFormatted = _formatDate(order['date']);
    final address = order['delivery_address'] ?? 'N/A';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFFFF7733),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black87),
                      children: [
                        const TextSpan(
                          text: "Delivery Address: ",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: address),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Ordered Products:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  ...items.map((item) {
                    final qty = item['quantity'] ?? 1;
                    final pid = item['product_id'] ?? item['sku'] ?? '-';
                    final name = item['name'] ?? 'Unknown Product';
                    final unitPrice =
                        (item['unit_price'] as num?)?.toDouble() ?? 0.0;
                    final imageUrl = getProductImageUrl(item);
                    final orderStatus = statusRaw; // Order status for eligibility check

                    return InkWell(
                      onTap: () async {
                        // Fetch full product details and navigate to product detail
                        try {
                          final products = await _apiService.getProducts();
                          final product = products.firstWhere(
                            (p) => (p['product_id'] ?? p['id']).toString() == pid.toString(),
                            orElse: () => {
                              'product_id': pid,
                              'id': pid,
                              'name': name,
                              ...item,
                            },
                          );
                          
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetail(product: product),
                            ),
                          );
                          // If we return from product detail, refresh eligibility
                          // This ensures eligibility is re-checked after order status changes
                          if (result == true && mounted) {
                            // Optionally refresh order list if needed
                            // _fetchOrders();
                          }
                        } catch (e) {
                          // If product not found, still navigate with available data
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProductDetail(
                                product: {
                                  'product_id': pid,
                                  'id': pid,
                                  'name': name,
                                  ...item,
                                },
                              ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: imageUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(7),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (ctx, err, stack) =>
                                            const Icon(
                                              Icons.broken_image,
                                              size: 20,
                                              color: Colors.grey,
                                            ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.computer,
                                      size: 24,
                                      color: Colors.grey,
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${qty}x(ID: $pid) $name",
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (orderStatus == 'delivered')
                                    const SizedBox(height: 2),
                                  if (orderStatus == 'delivered')
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Check if item has refund status
                                        if (item['refund_status'] != null) ...[
                                          Container(
                                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: item['refund_status'] == 'refunded' 
                                                  ? Colors.green.shade50 
                                                  : Colors.red.shade50,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: item['refund_status'] == 'refunded' 
                                                    ? Colors.green.shade300 
                                                    : Colors.red.shade300,
                                              ),
                                            ),
                                            child: Text(
                                              item['refund_status'] == 'refunded' 
                                                  ? "✓ Refund Accepted" 
                                                  : "✗ Refund Rejected",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: item['refund_status'] == 'refunded' 
                                                    ? Colors.green.shade700 
                                                    : Colors.red.shade700,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                        ],
                                        Row(
                                          children: [
                                            Text(
                                              "Tap to review",
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.green[700],
                                                fontStyle: FontStyle.italic,
                                              ),
                                            ),
                                            if (item['refund_status'] == null) ...[
                                              SizedBox(width: 8),
                                              GestureDetector(
                                                onTap: () => _showRefundDialog(context, order, item),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange.shade50,
                                                    borderRadius: BorderRadius.circular(4),
                                                    border: Border.all(color: Colors.orange.shade300),
                                                  ),
                                                  child: Text(
                                                    "Request Refund",
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.orange.shade700,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              "(${unitPrice.toStringAsFixed(2)} ₺)x($qty)",
                              style: const TextStyle(
                                fontFamily: 'Roboto',
                                color: Colors.black54,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Order Total:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "${totalAmount.toStringAsFixed(2)} ₺",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Color(0xFFFF7733),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Order Date",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    Text(
                      dateFormatted,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(statusRaw).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(statusRaw).withOpacity(0.5),
                    ),
                  ),
                  child: Text(
                    statusFormatted,
                    style: TextStyle(
                      color: _getStatusColor(statusRaw),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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

  Color _getStatusColor(String? status) {
    if (status == null) return Colors.grey;
    switch (status.toLowerCase()) {
      case 'delivered':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'in_transit':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.black87;
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
    
    // Check purchase date for 30-day window (from purchase, not delivery)
    DateTime? purchaseDate;
    if (order['created_at'] != null) {
      try {
        purchaseDate = DateTime.tryParse(order['created_at'].toString());
      } catch (e) {}
    }
    if (purchaseDate == null && order['date'] != null) {
      purchaseDate = DateTime.tryParse(order['date']);
    }
    
    bool isWithin30Days = true;
    String daysMessage = '';
    if (purchaseDate != null) {
      final daysSincePurchase = DateTime.now().difference(purchaseDate).inDays;
      isWithin30Days = daysSincePurchase <= 30;
      daysMessage = '$daysSincePurchase days since purchase';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(maxWidth: 600),
          padding: EdgeInsets.all(32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment_return, color: Color(0xFFFF7733), size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Request Refund',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF333333),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRefundInfoRow('Product', productName),
                      _buildRefundInfoRow('Order ID', '#$orderId'),
                      _buildRefundInfoRow('Quantity', quantity.toString()),
                      _buildRefundInfoRow('Unit Price', '\$${unitPrice.toStringAsFixed(2)}'),
                      _buildRefundInfoRow('Total Amount', '\$${totalPrice.toStringAsFixed(2)}'),
                      if (purchaseDate != null)
                        _buildRefundInfoRow('Purchase Date', 
                          '${purchaseDate.year}-${purchaseDate.month.toString().padLeft(2, '0')}-${purchaseDate.day.toString().padLeft(2, '0')}'),
                      if (daysMessage.isNotEmpty)
                        _buildRefundInfoRow('Time Since Purchase', daysMessage),
                    ],
                  ),
                ),
                if (!isWithin30Days) ...[
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'More than 30 days since purchase. Refund may not be eligible.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: 24),
                Text(
                  'Reason for Refund (Optional):',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Please provide a reason for your refund request...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.all(16),
                  ),
                  maxLines: 4,
                ),
                SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (context.mounted) {
                          Navigator.pop(context);
                          await _submitRefundRequest(orderId, productId, reasonController.text);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFF7733),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text('Submit Request', style: TextStyle(fontSize: 16)),
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

  Widget _buildRefundInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitRefundRequest(dynamic orderId, dynamic productId, String reason) async {
    try {
      final result = await _apiService.requestRefund(
        orderId.toString(),
        productId,
        reason,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result != null 
                ? 'Refund request submitted successfully'
                : 'Failed to submit refund request'),
            backgroundColor: result != null ? Colors.green : Colors.red,
          ),
        );
        // Refresh orders to show updated status
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
