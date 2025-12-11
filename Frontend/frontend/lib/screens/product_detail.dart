import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class ProductDetail extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetail({Key? key, required this.product}) : super(key: key);

  @override
  _ProductDetailState createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> {
  int _currentImageIndex = 0;
  final List<String> _productImages = ['Image 1', 'Image 2', 'Image 3'];
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();

  // State for reviews & eligibility
  List<dynamic> _publicReviews = [];
  Map<String, dynamic>? _myPendingReview;
  bool _isLoadingReviews = true;
  bool _canReview = false;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _commentController.addListener(() {
      setState(() {});
    });
  }

  // Refresh eligibility check - call this when returning from order history
  Future<void> refreshEligibilityCheck() async {
    await _loadReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    final api = ApiService();
    final productId = widget.product['product_id'] ?? widget.product['id'];

    // 1. Fetch Public Reviews (Sorted by backend)
    final public = await api.getPublicReviews(productId);

    // 2. Fetch Pending (if logged in)
    List<dynamic> pendingList = [];
    bool eligible = false;

    if (AuthService().isLoggedIn) {
      pendingList = await api.getMyPendingReviews();

      // 3. Check Eligibility
      String? uid;
      if (FirebaseAuth.instance.currentUser != null) {
        uid = FirebaseAuth.instance.currentUser!.uid;
      } else {
        uid =
            AuthService().currentUser?['id']?.toString() ??
            AuthService().currentUser?['user_id']?.toString();
      }

      if (uid != null) {
        eligible = await api.checkReviewEligibility(uid, productId);
      }
    } else {
      eligible = false;
    }

    // Filter pending list to find one for THIS product
    Map<String, dynamic>? pendingForThisProduct;
    try {
      pendingForThisProduct = pendingList.firstWhere(
        (r) => r['product_id'].toString() == productId.toString(),
      );
    } catch (e) {
      pendingForThisProduct = null;
    }

    if (mounted) {
      setState(() {
        _publicReviews = public;
        _myPendingReview = pendingForThisProduct;
        _canReview = eligible;
        _isLoadingReviews = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = getProductImageUrl(widget.product);
    final title = widget.product['name'] ?? 'Product Name';
    final price = widget.product['price'];
    final description = widget.product['description'] ?? '';
    final stock = widget.product['quantity_in_stock'] ?? 0;
    final distributor =
        widget.product['distributor_info'] ?? 'Unknown Supplier';
    final categoryNames = getCategoryNames(widget.product);
    final productId = widget.product['product_id'] ?? widget.product['id'];
    final bool isOutOfStock = stock == 0;

    return StoreLayout(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageCarousel(imageUrl, title, isOutOfStock),
              const SizedBox(height: 24),
              _buildProductInfo(
                title,
                price,
                stock,
                categoryNames,
                description,
                distributor,
                isOutOfStock,
              ),

              const SizedBox(height: 40),
              const Divider(),

              const Text(
                "Rate & Review",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF7733),
                ),
              ),
              const SizedBox(height: 16),
              _buildInteractiveRating(),
              const SizedBox(height: 16),
              _buildCommentBox(),

              if (AuthService().isLoggedIn && !_canReview) ...[
                const SizedBox(height: 8),
                Text(
                  "NOTE: You can only send comments on the products you received.",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    color:
                        (_commentController.text.isNotEmpty ||
                            _selectedRating > 0)
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              _buildSendButton(productId),

              const SizedBox(height: 40),
              const Divider(),
              const Text(
                "Reviews",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF7733),
                ),
              ),
              const SizedBox(height: 16),

              if (_isLoadingReviews)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF7733)),
                )
              else ...[
                if (_myPendingReview != null)
                  _buildPendingReviewCard(_myPendingReview!),

                if (_publicReviews.isEmpty && _myPendingReview == null)
                  const Text("No reviews yet."),

                _buildReviewsList(_publicReviews),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // --- Widgets ---

  Widget _buildSendButton(dynamic productId) {
    bool isLoggedIn = AuthService().isLoggedIn;
    bool isDisabled = false;

    if (isLoggedIn) {
      if (_selectedRating == 0 || !_canReview) {
        isDisabled = true;
      }
    } else {
      if (_selectedRating == 0) isDisabled = true;
    }

    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: isDisabled
            ? null
            : () async {
                if (!AuthService().isLoggedIn) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                  _loadReviews();
                  setState(() {});
                } else {
                  if (!_canReview) return;

                  bool success = await ApiService().postReview(
                    productId,
                    _selectedRating,
                    _commentController.text,
                  );

                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Review sent!")),
                    );
                    _commentController.clear();
                    setState(() => _selectedRating = 0);
                    // Refresh reviews to show new timestamped review
                    _loadReviews();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Failed to send review.")),
                    );
                  }
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDisabled ? Colors.grey : const Color(0xFFFF7733),
          foregroundColor: Colors.white,
        ),
        child: const Text("Send Review"),
      ),
    );
  }

  Widget _buildPendingReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow[50],
        border: Border.all(color: Colors.orange),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    "You (Pending)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(
                    5,
                    (i) => Icon(
                      i < (review['rating'] ?? 0)
                          ? Icons.star
                          : Icons.star_border,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () async {
                  await ApiService().deleteReview(
                    review['review_id'].toString(),
                  );
                  _loadReviews();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(review['comment'] ?? ''),
          const SizedBox(height: 8),

          // TIMESTAMP FOR PENDING REVIEW
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              _formatReviewDate(review['timestamp']),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

          const SizedBox(height: 4),
          const Text(
            "Your comment is waiting for approval",
            style: TextStyle(
              color: Colors.red,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList(List<dynamic> reviews) {
    return Column(children: reviews.map((r) => _buildReviewCard(r)).toList());
  }

  Widget _buildReviewCard(Map<String, dynamic> r) {
    String name = r['author_name'] ?? r['user_id']?.toString() ?? 'Customer';
    String formattedDate = _formatReviewDate(r['timestamp']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 10),
              ...List.generate(
                5,
                (i) => Icon(
                  i < (r['rating'] ?? 0) ? Icons.star : Icons.star_border,
                  size: 16,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Comment Text
          if (r['comment'] != null && r['comment'].toString().trim().isNotEmpty)
            Text(r['comment']),

          const SizedBox(height: 8),

          // Timestamp at the end
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              formattedDate,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Format Helper: "Date: 05-12-2025 21:01" or "Date: -"
  String _formatReviewDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) {
      return "Date: -";
    }
    try {
      final dt = DateTime.parse(isoString).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');

      return "Date: $day-$month-$year $hour:$minute";
    } catch (e) {
      return "Date: -";
    }
  }

  Widget _buildImageCarousel(String? url, String title, bool isOutOfStock) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF7733), width: 2),
      ),
      child: Stack(
        children: [
          Center(
            child: url != null
                ? Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFFFF7733),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, size: 100, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      );
                    },
                  )
                : const Icon(Icons.computer, size: 100, color: Colors.grey),
          ),
          if (isOutOfStock)
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Out of Stock',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          if (_currentImageIndex > 0)
            Positioned(
              left: 16,
              top: 0,
              bottom: 0,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios,
                  color: Color(0xFFFF7733),
                ),
                onPressed: () => setState(() => _currentImageIndex--),
              ),
            ),
          if (_currentImageIndex < _productImages.length - 1)
            Positioned(
              right: 16,
              top: 0,
              bottom: 0,
              child: IconButton(
                icon: const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFFFF7733),
                ),
                onPressed: () => setState(() => _currentImageIndex++),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductInfo(
    String title,
    dynamic price,
    dynamic stock,
    String cat,
    String desc,
    String distributor,
    bool isOutOfStock,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(cat, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 10),
        Text(
          "${price ?? 0} ₺",
          style: const TextStyle(
            fontSize: 24,
            color: Color(0xFFFF7733),
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          "$stock units in stock",
          style: TextStyle(
            color: isOutOfStock ? Colors.red : Colors.black,
            fontWeight: isOutOfStock ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 10),
        Text(desc),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isOutOfStock
                ? Colors.grey
                : const Color(0xFFFF7733),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: isOutOfStock
              ? null
              : () {
                  CartService().addToCart(widget.product);
                  setState(() {});
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Added to Cart")),
                  );
                },
          child: Text(
            isOutOfStock ? "Out of Stock" : "Add to Cart",
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractiveRating() {
    return Row(
      children: List.generate(5, (index) {
        return IconButton(
          icon: Icon(
            index < _selectedRating ? Icons.star : Icons.star_border,
            color: index < _selectedRating ? Colors.yellow[700] : Colors.grey,
            size: 32,
          ),
          onPressed: () {
            setState(() {
              if (_selectedRating == index + 1) {
                _selectedRating = 0;
              } else {
                _selectedRating = index + 1;
              }
            });
          },
        );
      }),
    );
  }

  Widget _buildCommentBox() {
    return TextField(
      controller: _commentController,
      maxLines: 3,
      decoration: const InputDecoration(
        hintText: "Comments with texts are evaluated around 2 work days",
        hintStyle: TextStyle(color: Colors.grey),
        border: OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}
