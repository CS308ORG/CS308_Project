import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import 'home_screen.dart';
import 'product_detail.dart';

class WishlistPage extends StatefulWidget {
  @override
  _WishlistPageState createState() => _WishlistPageState();
}

class _WishlistPageState extends State<WishlistPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _wishlist = [];
  bool _loading = true;
  Set<String> _wishlistProductIds = {};

  @override
  void initState() {
    super.initState();
    _fetchWishlist();
  }

  Future<void> _fetchWishlist() async {
    setState(() => _loading = true);
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null && AuthService().isLoggedIn) {
      final currentUser = AuthService().currentUser;
      uid = currentUser?['id']?.toString() ?? currentUser?['user_id']?.toString();
    }

    if (uid != null) {
      try {
        final wishlist = await _apiService.getWishlist(uid);
        setState(() {
          _wishlist = wishlist;
          _wishlistProductIds = wishlist.map((p) => (p['id'] ?? p['product_id']).toString()).toSet();
          _loading = false;
        });
      } catch (e) {
        print("Error fetching wishlist: $e");
        setState(() {
          _wishlist = [];
          _wishlistProductIds = {};
          _loading = false;
        });
      }
    } else {
      setState(() => _loading = false);
    }
  }

  Future<void> _removeFromWishlist(String productId) async {
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null && AuthService().isLoggedIn) {
      final currentUser = AuthService().currentUser;
      uid = currentUser?['id']?.toString() ?? currentUser?['user_id']?.toString();
    }

    if (uid == null) return;

    try {
      final success = await _apiService.removeFromWishlist(uid, productId);
      if (success) {
        setState(() {
          _wishlist.removeWhere((p) => (p['id'] ?? p['product_id']).toString() == productId);
          _wishlistProductIds.remove(productId);
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from wishlist'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove from wishlist'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String? getProductImageUrl(Map<String, dynamic> product) {
    final keys = [
      'imageUrl',
      'image_url',
      'image',
      'thumbnailUrl',
      'thumbnail_url',
    ];
    for (final key in keys) {
      if (product[key] != null && product[key].toString().isNotEmpty) {
        return product[key].toString();
      }
    }
    return null;
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final imageUrl = getProductImageUrl(product);
    final int stock = product['quantity_in_stock'] ?? 0;
    final bool isOutOfStock = stock == 0;
    final rating = product['average_rating'] ?? 0.0;
    final price = product['price'] ?? 0;

    // Calculate max allowed (Lowest of stock or 10)
    final int maxAllowed = min(stock, 10);

    // Check quantity in cart
    final cartItem = CartService().items.firstWhere(
      (item) =>
          (item['id'] ?? item['product_id']).toString() ==
          (product['product_id'] ?? product['id']).toString(),
      orElse: () => {},
    );
    final int currentCartQty = cartItem['quantity'] ?? 0;

    // Disable if cart quantity reached max allowed
    final bool canAddToCart = currentCartQty < maxAllowed;

    return ProductCardWidget(
      product: product,
      imageUrl: imageUrl,
      isOutOfStock: isOutOfStock,
      canAddToCart: canAddToCart,
      stock: stock,
      rating: rating,
      price: price,
      onTap: () async {
        // Products in wishlist are always wishlisted
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetail(
              product: product,
              initialWishlistStatus: true, // Always true since it's from wishlist
            ),
          ),
        );
        if (result == true) {
          _fetchWishlist();
        }
      },
      onAddToCart: () {
        CartService().addToCart(product);
        setState(() {});
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StoreLayout(
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7733)),
            )
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Wrapper for Margins - 1080 MaxWidth (same as main menu)
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "My Wishlist",
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w300,
                                letterSpacing: 1.2,
                                color: Color(0xFFFF7733),
                              ),
                            ),
                            const SizedBox(height: 24),
                            if (_wishlist.isEmpty)
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: Text(
                                    "Your wishlist is empty.",
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              )
                            else
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  childAspectRatio: 0.68,
                                  crossAxisSpacing: 24,
                                  mainAxisSpacing: 24,
                                ),
                                itemCount: _wishlist.length,
                                itemBuilder: (context, index) {
                                  final product = _wishlist[index];
                                  return _buildProductCard(product);
                                },
                              ),
                          ],
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

