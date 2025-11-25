import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import 'credit_card_page.dart';
import 'home_screen.dart'; // Required for StoreLayout and getProductImageUrl

class BasketPage extends StatefulWidget {
  @override
  _BasketPageState createState() => _BasketPageState();
}

class _BasketPageState extends State<BasketPage> {
  final CartService _cartService = CartService();

  @override
  Widget build(BuildContext context) {
    // Requirement 3.5: Wrapped in StoreLayout to show Header, Categories, and Search
    return StoreLayout(
      // If we wanted to highlight a category or search specific to basket, we could pass args here.
      // For now, we leave them null to show the default "all" state.
      body: _cartService.items.isEmpty ? _buildEmptyCart() : _buildFilledCart(),
    );
  }

  Widget _buildFilledCart() {
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 700),
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            // Page Title (Since AppBar is gone, we add a title text here)
            Text(
              'Your Basket (${_cartService.itemCount} items)',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7733),
              ),
            ),
            SizedBox(height: 24),

            // List of Items
            // We use shrinkWrap and physics because StoreLayout already provides a SingleChildScrollView
            // However, since this list might be long, we can keep it inside a container with height
            // OR let it expand. Here we let it expand naturally within the parent scroll view.
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _cartService.items.length,
              itemBuilder: (context, index) {
                return _buildBasketItem(_cartService.items[index], index);
              },
            ),
            SizedBox(height: 24),

            // Total Price
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                'Total Price: ${_cartService.totalPrice.toStringAsFixed(2)} TL',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF7733),
                ),
              ),
            ),
            SizedBox(height: 24),

            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Go Back Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  label: Text('Go Back'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF7733),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(width: 16),

                // Next Button
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            CreditCardPage(totalPrice: _cartService.totalPrice),
                      ),
                    );
                  },
                  icon: Icon(Icons.arrow_forward, color: Colors.white),
                  label: Text('Next'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF7733),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            SizedBox(height: 24),
          ],
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
            Icon(Icons.shopping_cart_outlined, size: 100, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Your cart is empty',
              style: TextStyle(fontSize: 24, color: Colors.grey[600]),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Continue Shopping'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF7733),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasketItem(Map<String, dynamic> item, int index) {
    final imageUrl = getProductImageUrl(item); // Helper from home_screen.dart

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFFF7733), width: 2),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 100,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Colors.grey[400],
                      ),
                    ),
                  )
                : Icon(Icons.computer, size: 40, color: Colors.grey[600]),
          ),
          SizedBox(width: 16),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Product',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFFF7733),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${item['price']?.toStringAsFixed(2) ?? '0.00'} TL',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'x${item['quantity']}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Remove Button
          IconButton(
            icon: Icon(Icons.delete, color: Colors.red, size: 28),
            onPressed: () {
              setState(() {
                _cartService.removeFromCart(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Item removed from basket'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
