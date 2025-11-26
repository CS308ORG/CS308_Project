import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cart_service.dart';
import 'credit_card_page.dart';
import 'home_screen.dart'; // For StoreLayout and getProductImageUrl

class BasketPage extends StatefulWidget {
  @override
  _BasketPageState createState() => _BasketPageState();
}

class _BasketPageState extends State<BasketPage> {
  final CartService _cartService = CartService();

  @override
  Widget build(BuildContext context) {
    return StoreLayout(
      body: _cartService.items.isEmpty ? _buildEmptyCart() : _buildFilledCart(),
    );
  }

  Widget _buildFilledCart() {
    // Fix 4.0: Wrapped in SingleChildScrollView to prevent overflow
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 800),
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Your Basket (${_cartService.itemCount} items)',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF7733),
                ),
              ),
              SizedBox(height: 24),

              // Cart Items List
              ListView.builder(
                shrinkWrap: true,
                physics:
                    NeverScrollableScrollPhysics(), // Scroll handled by SingleChildScrollView
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
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.arrow_back, color: Colors.white),
                    label: Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF7733),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CreditCardPage(
                            totalPrice: _cartService.totalPrice,
                          ),
                        ),
                      );
                    },
                    icon: Icon(Icons.arrow_forward, color: Colors.white),
                    label: Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF7733),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
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
              onPressed: () => Navigator.pop(context),
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
    final imageUrl = getProductImageUrl(item);
    // Logic: Limits
    int quantity = item['quantity'] ?? 1;
    int stock = item['quantity_in_stock'] ?? item['stock_quantity'] ?? 10;
    int maxLimit = stock < 10 ? stock : 10; // Cap at 10 or stock

    // Logic: Item Total Cost (4.1.0.3)
    double unitPrice = item['price'] ?? 0.0;
    double itemTotal = unitPrice * quantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFF7733), width: 2),
      ),
      child: Row(
        children: [
          // Image
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(4),
            ),
            child: imageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  )
                : const Icon(Icons.computer, size: 40, color: Colors.grey),
          ),
          const SizedBox(width: 16),

          // Info & Controls
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Product',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Unit: ${unitPrice.toStringAsFixed(2)} TL',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),

                const SizedBox(height: 8),

                // Quantity Controls (4.1.0.2)
                Row(
                  children: [
                    // Minus Button
                    InkWell(
                      onTap: quantity > 1
                          ? () => setState(
                              () => _cartService.updateQuantity(
                                index,
                                quantity - 1,
                              ),
                            )
                          : null,
                      child: Icon(
                        Icons.remove_circle,
                        color: quantity > 1
                            ? const Color(0xFFFF7733)
                            : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Count Display
                    Text(
                      '$quantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Plus Button
                    InkWell(
                      onTap: quantity < maxLimit
                          ? () => setState(
                              () => _cartService.updateQuantity(
                                index,
                                quantity + 1,
                              ),
                            )
                          : null,
                      child: Icon(
                        Icons.add_circle,
                        color: quantity < maxLimit
                            ? const Color(0xFFFF7733)
                            : Colors.grey,
                        size: 28,
                      ),
                    ),
                    const Spacer(),
                    // Item Total Cost (4.1.0.3)
                    Text(
                      '${itemTotal.toStringAsFixed(2)} TL',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7733),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Delete Button
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () {
              setState(() => _cartService.removeFromCart(index));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Item removed'),
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
