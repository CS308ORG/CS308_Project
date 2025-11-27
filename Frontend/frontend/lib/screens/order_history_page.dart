import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart'; // ADDED: Required for seeded user access
import 'home_screen.dart'; // Contains getProductImageUrl

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
    // 1. Try getting ID from Firebase (Real Auth)
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    // 2. If null, try getting ID from Custom AuthService (Seeded Auth)
    if (uid == null && AuthService().isLoggedIn) {
      final currentUser = AuthService().currentUser;
      // Handle both 'id' (string doc ID) or 'user_id' (int field)
      uid =
          currentUser?['id']?.toString() ?? currentUser?['user_id']?.toString();
    }

    if (uid != null) {
      try {
        // Fetch orders from API
        List<dynamic> fetchedOrders = await _apiService.getUserOrders(uid);

        // --- SIMULATED DATA FALLBACK (If API returns empty) ---
        if (fetchedOrders.isEmpty) {
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
        }
        // -----------------------------------------------

        // SORTING LOGIC
        fetchedOrders.sort((a, b) {
          final dateAStr = a['date'] as String?;
          final dateBStr = b['date'] as String?;
          final priceA = (a['total_amount'] as num?)?.toDouble() ?? 0.0;
          final priceB = (b['total_amount'] as num?)?.toDouble() ?? 0.0;

          if (dateAStr == null && dateBStr == null)
            return priceB.compareTo(priceA);
          if (dateAStr == null) return 1;
          if (dateBStr == null) return -1;

          final dateA = DateTime.tryParse(dateAStr);
          final dateB = DateTime.tryParse(dateBStr);

          if (dateA != null && dateB != null) {
            int dateComparison = dateB.compareTo(dateA);
            if (dateComparison != 0) return dateComparison;
          }

          return priceB.compareTo(priceA);
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
      // Stop loading if no user is found at all
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Helper to format status strings
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
        if (status.length > 1) {
          return status[0].toUpperCase() + status.substring(1);
        }
        return status.toUpperCase();
    }
  }

  /// Helper to format date
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
    // RESOLVE USER INFO FOR DISPLAY
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
                      // --- Header Section ---
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
                            // User Info Card
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

                      // --- Orders List ---
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
            // Delivery Address Header
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

            // --- Inner Card (Item List) ---
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
                    // Format requested: ([Product Price])x([quantity])
                    // We assume product price means Unit Price here.
                    final imageUrl = getProductImageUrl(item);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          // 1. Thumbnail
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

                          // 2. [Qty]x(ID: [ID]) [Title]
                          Expanded(
                            child: Text(
                              "${qty}x(ID: $pid) $name",
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          const SizedBox(width: 16),

                          // 3. ([Product Price])x([Qty])
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
                    );
                  }).toList(),

                  const Divider(height: 24),

                  // Order Total
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

            // --- End Inner Card ---
            const SizedBox(height: 16),

            // Footer: Date and Status
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
}
