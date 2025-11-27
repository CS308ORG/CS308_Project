import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Needed for direct ID access check if using Firebase
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
  bool _canReview = false; // Stores eligibility result from backend

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _commentController.addListener(() {
      // Force rebuild to update warning color if text changes
      setState(() {});
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadReviews() async {
    final api = ApiService();
    final productId = widget.product['product_id'] ?? widget.product['id'];

    // 1. Fetch Public Reviews
    final public = await api.getPublicReviews(productId);

    // 2. Fetch Pending (if logged in)
    List<dynamic> pendingList = [];
    bool eligible = false;

    if (AuthService().isLoggedIn) {
      pendingList = await api.getMyPendingReviews();

      // 3. Check Eligibility
      String? uid;
      // Get correct UID (Firebase or Seeded)
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
      // If not logged in, we set eligible to true purely for UI state (button takes to login),
      // or false to hide things.
      // Requirement: "logged out state comment algorithm will run as usual"
      // Usually this means button is enabled but redirects.
      // However, for the warning text logic, we only show warning if logged in AND not eligible.
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

    return StoreLayout(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageCarousel(imageUrl, title),
              const SizedBox(height: 24),
              _buildProductInfo(
                title,
                price,
                stock,
                categoryNames,
                description,
                distributor,
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

              // WARNING NOTE LOGIC
              if (AuthService().isLoggedIn && !_canReview) ...[
                const SizedBox(height: 8),
                Text(
                  "NOTE: You can only send comments on the products you received.",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    // Red if user typed/rated, Orange otherwise
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

    // If Logged OUT: Button enabled (to redirect).
    // If Logged IN: Button disabled if Rating is 0 OR Not Eligible.
    bool isDisabled = false;
    if (isLoggedIn) {
      if (_selectedRating == 0 || !_canReview) {
        isDisabled = true;
      }
    } else {
      // Logged out: Disable if rating is 0 (standard behavior)
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
                  // Refresh upon return
                  _loadReviews();
                  setState(() {});
                } else {
                  // Double check eligibility before sending (though backend enforces it too)
                  if (!_canReview) return;

                  // Post to Backend
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
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
          const SizedBox(width: 10),
          Expanded(child: Text(r['comment'] ?? '')),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(String? url, String title) {
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
                ? Image.network(url, fit: BoxFit.contain)
                : const Icon(Icons.computer, size: 100, color: Colors.grey),
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
        Text("$stock units in stock"),
        const SizedBox(height: 10),
        Text(desc),
        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF7733),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          onPressed: () {
            CartService().addToCart(widget.product);
            setState(() {});
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text("Added to Cart")));
          },
          child: const Text("Add to Cart", style: TextStyle(fontSize: 18)),
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
              // Toggle logic: If clicking the same star count, reset to 0
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
