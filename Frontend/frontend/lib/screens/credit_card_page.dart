import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import 'invoice_page.dart';

class CreditCardPage extends StatefulWidget {
  final double totalPrice;

  const CreditCardPage({required this.totalPrice});

  @override
  _CreditCardPageState createState() => _CreditCardPageState();
}

class _CreditCardPageState extends State<CreditCardPage> {
  String _selectedPaymentMethod = 'credit_card';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        title: Text('Credit Card Page'),
        backgroundColor: Color(0xFFFF7733),
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Total Price
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Total Price: ${widget.totalPrice.toStringAsFixed(2)}TL',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFF7733),
                  ),
                ),
              ),
              SizedBox(height: 40),

              // Payment Options
              _buildPaymentOption(
                'credit_card',
                'Creedit Card: Ecem Akbank 51**',
                Icons.credit_card,
              ),
              SizedBox(height: 16),
              _buildPaymentOption(
                'alternative',
                'Alternative Payment Method',
                Icons.payment,
              ),
              SizedBox(height: 16),
              _buildPaymentOption(
                'multipay',
                'Multipay',
                Icons.account_balance_wallet,
              ),
              SizedBox(height: 60),

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
                      _processCheckout();
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon) {
    bool isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPaymentMethod = value;
        });
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFFF7733) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Color(0xFFFF7733),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Color(0xFFFF7733),
              size: 24,
            ),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : Colors.black,
                ),
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedPaymentMethod,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedPaymentMethod = newValue!;
                });
              },
              activeColor: Colors.white,
              fillColor: MaterialStateProperty.all(
                isSelected ? Colors.white : Color(0xFFFF7733),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _processCheckout() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final cartService = CartService();
      final authService = AuthService();
      final apiService = ApiService();

      // Get current user ID
      final userId = authService.currentUser?['id']?.toString() ??
          authService.currentUser?['user_id']?.toString();

      if (userId == null) {
        Navigator.pop(context); // Close loading
        _showErrorDialog('You must be logged in to checkout');
        return;
      }

      // Get cart items
      final cartItems = cartService.items;
      if (cartItems.isEmpty) {
        Navigator.pop(context); // Close loading
        _showErrorDialog('Your cart is empty');
        return;
      }

      // Call checkout endpoint
      final result = await apiService.checkout(userId, cartItems);

      Navigator.pop(context); // Close loading

      if (result != null && result['success'] == true) {
        // Clear cart after successful checkout
        await cartService.clearCart();
        
        // Prepare order data with all necessary fields
        final orderData = result['order'] ?? result;
        // Ensure total_amount and date are present
        if (orderData['total_amount'] == null || orderData['total_amount'] == 0) {
          orderData['total_amount'] = widget.totalPrice;
        }
        if (orderData['date'] == null && orderData['created_at'] == null) {
          orderData['date'] = DateTime.now().toIso8601String();
        }
        
        // Navigate to invoice page instead of showing dialog
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => InvoicePage(orderData: orderData),
          ),
        );
      } else {
        _showErrorDialog('Checkout failed. Please try again.');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading
      _showErrorDialog('An error occurred: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Color(0xFFFF7733))),
          ),
        ],
      ),
    );
  }
}
