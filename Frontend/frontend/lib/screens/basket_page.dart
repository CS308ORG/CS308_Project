import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import 'credit_card_page.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class BasketPage extends StatefulWidget {
  @override
  _BasketPageState createState() => _BasketPageState();
}

class _BasketPageState extends State<BasketPage> with SingleTickerProviderStateMixin {
  final CartService _cartService = CartService();
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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreLayout(
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _cartService.items.isEmpty ? _buildEmptyCart() : _buildFilledCart(),
      ),
    );
  }

  Widget _buildFilledCart() {
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF1E3A8A),
                      Color(0xFF3B82F6),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0xFF1E3A8A).withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shopping_cart_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Your Shopping Cart',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${_cartService.itemCount} ${_cartService.itemCount == 1 ? 'item' : 'items'}',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Cart Items
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cartService.items.length,
                itemBuilder: (context, index) {
                  return _buildBasketItem(_cartService.items[index], index);
                },
              ),
              const SizedBox(height: 24),

              // Summary Card
              Container(
                padding: const EdgeInsets.all(24),
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
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subtotal',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${_cartService.totalPrice.toStringAsFixed(2)} TL',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 12),
                    Divider(),
                    SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        Text(
                          '${_cartService.totalPrice.toStringAsFixed(2)} TL',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Color(0xFF1E3A8A),
                          width: 2,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.arrow_back_rounded,
                                  color: Color(0xFF1E3A8A),
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Continue Shopping',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E3A8A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0xFF1E3A8A),
                            Color(0xFF3B82F6),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF1E3A8A).withOpacity(0.4),
                            blurRadius: 15,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () async {
                            final isLoggedIn = AuthService().isLoggedIn;

                            if (!isLoggedIn) {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoginScreen(),
                                ),
                              );
                              if (AuthService().isLoggedIn) {
                                setState(() {});
                              }
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CreditCardPage(
                                    totalPrice: _cartService.totalPrice,
                                  ),
                                ),
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Proceed to Checkout',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 100,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Your cart is empty',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add some items to get started!',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 40),
            Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF3B82F6),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1E3A8A).withOpacity(0.4),
                    blurRadius: 15,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Continue Shopping',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
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

  Widget _buildBasketItem(Map<String, dynamic> item, int index) {
    final imageUrl = getProductImageUrl(item);
    int quantity = item['quantity'] ?? 1;
    int stock = item['quantity_in_stock'] ?? 0;
    int maxLimit = min(stock, 10);

    double unitPrice = (item['price'] is int)
        ? (item['price'] as int).toDouble()
        : (item['price'] ?? 0.0);
    double itemTotal = unitPrice * quantity;

    TextEditingController qtyController = TextEditingController(
      text: quantity.toString(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            offset: Offset(0, 5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: imageUrl != null
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1E3A8A),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: Colors.grey[400],
                          );
                        },
                      )
                    : Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey[400]),
              ),
            ),
            const SizedBox(width: 16),

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['name'] ?? 'Product',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${unitPrice.toStringAsFixed(2)} TL per unit',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quantity Controls
                  Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: quantity > 1
                              ? Color(0xFF1E3A8A).withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: quantity > 1
                                ? Color(0xFF1E3A8A)
                                : Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: quantity > 1
                                ? () => setState(
                                      () => _cartService.updateQuantity(
                                        index,
                                        quantity - 1,
                                      ),
                                    )
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.remove_rounded,
                                color: quantity > 1
                                    ? Color(0xFF1E3A8A)
                                    : Colors.grey[400],
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 50,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextField(
                          controller: qtyController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (value) {
                            int? newVal = int.tryParse(value);
                            if (newVal == null) newVal = 1;
                            if (newVal > maxLimit) newVal = maxLimit;
                            if (newVal < 1) newVal = 1;
                            setState(() {
                              _cartService.updateQuantity(index, newVal!);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: quantity < maxLimit
                              ? Color(0xFF1E3A8A).withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: quantity < maxLimit
                                ? Color(0xFF1E3A8A)
                                : Colors.grey[300]!,
                            width: 1.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: quantity < maxLimit
                                ? () => setState(
                                      () => _cartService.updateQuantity(
                                        index,
                                        quantity + 1,
                                      ),
                                    )
                                : null,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.add_rounded,
                                color: quantity < maxLimit
                                    ? Color(0xFF1E3A8A)
                                    : Colors.grey[400],
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${itemTotal.toStringAsFixed(2)} TL',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A8A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),
            // Delete Button
            Container(
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    setState(() => _cartService.removeFromCart(index));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Text('Item removed from cart'),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.red[700],
                      size: 24,
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
