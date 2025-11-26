import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Kept for types if needed, but logic uses AuthService
import '../services/cart_service.dart';
import '../services/auth_service.dart'; // Required for AuthService
import 'home_screen.dart'; // StoreLayout
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

  // Rating & Comment State
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _hasSentReview = false;

  @override
  Widget build(BuildContext context) {
    final imageUrl = getProductImageUrl(
      widget.product,
    ); // Helper from home_screen
    final title = widget.product['name'] ?? 'Product Name';
    final price = widget.product['price'];
    final description = widget.product['description'] ?? '';
    final stock = widget.product['quantity_in_stock'] ?? 0;
    final distributor =
        widget.product['distributor_info'] ?? 'Unknown Supplier';
    final categoryNames = getCategoryNames(
      widget.product,
    ); // Helper from home_screen

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
              const SizedBox(height: 16),
              _buildSendButton(),
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
              if (_hasSentReview) _buildPendingReviewCard(),
              _buildReviewsList(),
            ],
          ),
        ),
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
                : Icon(Icons.computer, size: 100, color: Colors.grey),
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
              _selectedRating = index + 1;
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

  Widget _buildSendButton() {
    bool isGrayedOut = _selectedRating == 0;
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton(
        onPressed: isGrayedOut
            ? null
            : () async {
                // FIXED: Use AuthService to check backend login status
                final isLoggedIn = AuthService().isLoggedIn;

                if (!isLoggedIn) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                  if (result == true) setState(() {});
                } else {
                  setState(() {
                    _hasSentReview = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Review submitted for approval!"),
                    ),
                  );
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: isGrayedOut ? Colors.grey : const Color(0xFFFF7733),
          foregroundColor: Colors.white,
        ),
        child: const Text("Send Review"),
      ),
    );
  }

  Widget _buildPendingReviewCard() {
    bool hasText = _commentController.text.isNotEmpty;
    String userName = AuthService().userName;
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
                  Text(
                    userName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  ...List.generate(
                    5,
                    (i) => Icon(
                      i < _selectedRating ? Icons.star : Icons.star_border,
                      size: 16,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () {
                  setState(() {
                    _hasSentReview = false;
                    _commentController.clear();
                    _selectedRating = 0;
                  });
                },
              ),
            ],
          ),
          if (hasText) ...[
            const SizedBox(height: 8),
            Text(_commentController.text),
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
        ],
      ),
    );
  }

  Widget _buildReviewsList() {
    return Column(
      children: [
        _buildReviewCard("User1", 5, "Great product!"),
        _buildReviewCard("User2", 4, "Good value."),
      ],
    );
  }

  Widget _buildReviewCard(String user, int stars, String txt) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(user, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          ...List.generate(
            5,
            (i) => Icon(
              i < stars ? Icons.star : Icons.star_border,
              size: 16,
              color: Colors.orange,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(txt)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFF7733),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}
