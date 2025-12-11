import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart'; // ADDED: Required for AuthService().isLoggedIn
import 'credit_card_page.dart';
import 'home_screen.dart'; // For StoreLayout
import 'login_screen.dart'; // ADDED: Required for LoginScreen() navigation

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
    return SingleChildScrollView(
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                'Your Basket (${_cartService.itemCount} items)',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF7733),
                ),
              ),
              const SizedBox(height: 24),

              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _cartService.items.length,
                itemBuilder: (context, index) {
                  return _buildBasketItem(_cartService.items[index], index);
                },
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  'Total Price: ${_cartService.totalPrice.toStringAsFixed(2)} TL',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7733),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text('Go Back'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7733),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // NEXT BUTTON with LOGIN CHECK
                  ElevatedButton.icon(
                    onPressed: () async {
                      final isLoggedIn = AuthService().isLoggedIn;

                      if (!isLoggedIn) {
                        // Forward to Login
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => LoginScreen(),
                          ),
                        );
                        // Check if logged in upon return
                        if (AuthService().isLoggedIn) {
                          setState(() {});
                        }
                      } else {
                        // Already logged in, proceed
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
                    icon: const Icon(Icons.arrow_forward, color: Colors.white),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7733),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
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
            const Icon(
              Icons.shopping_cart_outlined,
              size: 100,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(fontSize: 24, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Continue Shopping'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7733),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
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
    int stock = item['quantity_in_stock'] ?? 10;
    int maxLimit = stock < 10 ? stock : 10;

    double unitPrice = (item['price'] is int)
        ? (item['price'] as int).toDouble()
        : (item['price'] ?? 0.0);
    double itemTotal = unitPrice * quantity;

    TextEditingController qtyController = TextEditingController(
      text: quantity.toString(),
    );

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
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFFF7733),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.broken_image, size: 40, color: Colors.grey);
                      },
                    ),
                  )
                : const Icon(Icons.computer, size: 40, color: Colors.grey),
          ),
          const SizedBox(width: 16),

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
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),

                Row(
                  children: [
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
                    const SizedBox(width: 8),

                    Container(
                      width: 40,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: TextField(
                        controller: qtyController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.only(bottom: 14),
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

                    const SizedBox(width: 8),
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

                    Text(
                      '${itemTotal.toStringAsFixed(2)} TL',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7733),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),
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
