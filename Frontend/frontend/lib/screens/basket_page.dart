import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import 'credit_card_page.dart';

class BasketPage extends StatefulWidget {
  @override
  _BasketPageState createState() => _BasketPageState();
}

class _BasketPageState extends State<BasketPage> {
  final CartService _cartService = CartService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        title: Text('Basket Page (${_cartService.itemCount} items)'),
        backgroundColor: Color(0xFFFF7733),
      ),
      body: _cartService.items.isEmpty
          ? _buildEmptyCart()
          : Center(
              child: Container(
                constraints: BoxConstraints(maxWidth: 700),
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: _cartService.items.length,
                        itemBuilder: (context, index) {
                          return _buildBasketItem(_cartService.items[index], index);
                        },
                      ),
                    ),
                    SizedBox(height: 24),

                    // Total Price
                    Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Total Price: ${_cartService.totalPrice.toStringAsFixed(2)}TL',
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
                                builder: (context) => CreditCardPage(totalPrice: _cartService.totalPrice),
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
            ),
    );
  }

  Widget _buildEmptyCart() {
    return Center(
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
    );
  }

  Widget _buildBasketItem(Map<String, dynamic> item, int index) {
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
            child: Icon(Icons.computer, size: 40, color: Colors.grey[600]),
          ),
          SizedBox(width: 16),

          // Product Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Product',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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