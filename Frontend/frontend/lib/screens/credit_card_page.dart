import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  
  bool _isProcessing = false;
  String _cardType = '';

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  // Detect card type based on number
  void _detectCardType(String cardNumber) {
    String cleanNumber = cardNumber.replaceAll(' ', '');
    setState(() {
      if (cleanNumber.startsWith('4')) {
        _cardType = 'Visa';
      } else if (cleanNumber.startsWith('5')) {
        _cardType = 'Mastercard';
      } else if (cleanNumber.startsWith('3')) {
        _cardType = 'Amex';
      } else {
        _cardType = '';
      }
    });
  }

  // Format card number with spaces
  String _formatCardNumber(String value) {
    String cleanValue = value.replaceAll(' ', '');
    String formatted = '';
    for (int i = 0; i < cleanValue.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += ' ';
      }
      formatted += cleanValue[i];
    }
    return formatted;
  }

  // Format expiry date with /
  String _formatExpiry(String value) {
    String cleanValue = value.replaceAll('/', '');
    if (cleanValue.length >= 2) {
      return cleanValue.substring(0, 2) + '/' + cleanValue.substring(2);
    }
    return cleanValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        title: Text('Payment'),
        backgroundColor: Color(0xFFFF7733),
      ),
      body: SingleChildScrollView(
        child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 500),
            padding: EdgeInsets.all(24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                // Total Price Card
              Container(
                  padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFFF7733), Color(0xFFFF9955)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        '\$${widget.totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                  color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24),

                // Payment Method Selection
                Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 16),

              // Payment Options
              _buildPaymentOption(
                'credit_card',
                  'Credit Card',
                Icons.credit_card,
              ),
                SizedBox(height: 12),
              _buildPaymentOption(
                'alternative',
                'Alternative Payment Method',
                Icons.payment,
              ),
                SizedBox(height: 12),
              _buildPaymentOption(
                'multipay',
                'Multipay',
                Icons.account_balance_wallet,
              ),
                SizedBox(height: 24),

                // Credit Card Form (only visible when credit_card is selected)
                if (_selectedPaymentMethod == 'credit_card') ...[
                  _buildCreditCardForm(),
                  SizedBox(height: 24),
                ],

              // Buttons
              Row(
                children: [
                  // Go Back Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isProcessing ? null : () {
                      Navigator.pop(context);
                    },
                        icon: Icon(Icons.arrow_back),
                    label: Text('Go Back'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Color(0xFFFF7733),
                          side: BorderSide(color: Color(0xFFFF7733)),
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                    SizedBox(width: 16),
                    // Pay Now Button
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _processPayment,
                        icon: _isProcessing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(Icons.payment),
                        label: Text(_isProcessing ? 'Processing...' : 'Pay Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFFF7733),
                      foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ),
                ],
              ),
            ],
            ),
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
              fillColor: WidgetStateProperty.all(
                isSelected ? Colors.white : Color(0xFFFF7733),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditCardForm() {
    return Form(
      key: _formKey,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Card Details',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_cardType.isNotEmpty)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFFFF7733).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      _cardType,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7733),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 16),

            // Card Number
            TextFormField(
              controller: _cardNumberController,
              decoration: InputDecoration(
                labelText: 'Card Number',
                hintText: '1234 5678 9012 3456',
                prefixIcon: Icon(Icons.credit_card, color: Color(0xFFFF7733)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFFFF7733), width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(16),
              ],
              onChanged: (value) {
                _detectCardType(value);
                String formatted = _formatCardNumber(value);
                if (formatted != _cardNumberController.text) {
                  _cardNumberController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(offset: formatted.length),
                  );
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter card number';
                }
                String cleanValue = value.replaceAll(' ', '');
                if (cleanValue.length < 13 || cleanValue.length > 16) {
                  return 'Card number must be 13-16 digits';
                }
                return null;
              },
            ),
            SizedBox(height: 12),

            // Card Holder Name
            TextFormField(
              controller: _cardHolderController,
              decoration: InputDecoration(
                labelText: 'Cardholder Name',
                hintText: 'JOHN DOE',
                prefixIcon: Icon(Icons.person, color: Color(0xFFFF7733)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFFFF7733), width: 2),
                ),
              ),
              textCapitalization: TextCapitalization.characters,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter cardholder name';
                }
                if (value.length < 3) {
                  return 'Name is too short';
                }
                return null;
              },
            ),
            SizedBox(height: 12),

            // Expiry Date and CVV
            Row(
              children: [
                // Expiry Date
                Expanded(
                  child: TextFormField(
                    controller: _expiryController,
                    decoration: InputDecoration(
                      labelText: 'Expiry Date',
                      hintText: 'MM/YY',
                      prefixIcon: Icon(Icons.calendar_today, color: Color(0xFFFF7733)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFFFF7733), width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    onChanged: (value) {
                      String formatted = _formatExpiry(value);
                      if (formatted != _expiryController.text) {
                        _expiryController.value = TextEditingValue(
                          text: formatted,
                          selection: TextSelection.collapsed(offset: formatted.length),
                        );
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      String cleanValue = value.replaceAll('/', '');
                      if (cleanValue.length != 4) {
                        return 'Invalid';
                      }
                      int? month = int.tryParse(cleanValue.substring(0, 2));
                      if (month == null || month < 1 || month > 12) {
                        return 'Invalid month';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 12),
                // CVV
                Expanded(
                  child: TextFormField(
                    controller: _cvvController,
                    decoration: InputDecoration(
                      labelText: 'CVV',
                      hintText: '123',
                      prefixIcon: Icon(Icons.lock, color: Color(0xFFFF7733)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFFFF7733), width: 2),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Required';
                      }
                      if (value.length < 3 || value.length > 4) {
                        return 'Invalid';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),

            // Security Notice
            Container(
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.green, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your payment information is secure.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.green[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processPayment() async {
    // Validate credit card form if credit card is selected
    if (_selectedPaymentMethod == 'credit_card') {
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }

    setState(() => _isProcessing = true);

    try {
      final cartService = CartService();
      final authService = AuthService();
      final apiService = ApiService();

      // Get current user ID
      final userId = authService.currentUser?['id']?.toString() ??
          authService.currentUser?['user_id']?.toString();

      if (userId == null) {
        _showErrorDialog('You must be logged in to checkout');
        return;
      }

      // Get cart items
      final cartItems = cartService.items;
      if (cartItems.isEmpty) {
        _showErrorDialog('Your cart is empty');
        return;
      }

      // Call checkout endpoint
      // Note: Credit card verification is out of scope per project requirements
      final result = await apiService.checkout(userId, cartItems);

      if (result != null && result['success'] == true) {
        // Clear cart after successful checkout
        await cartService.clearCart();
        
        // Prepare order data
        final orderData = result['order'] ?? result;
        if (orderData['total_amount'] == null || orderData['total_amount'] == 0) {
          orderData['total_amount'] = widget.totalPrice;
        }
        if (orderData['date'] == null && orderData['created_at'] == null) {
          orderData['date'] = DateTime.now().toIso8601String();
        }
        
        // Navigate to invoice page
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => InvoicePage(orderData: orderData),
          ),
        );
      } else {
        _showErrorDialog('Payment failed. Please try again.');
      }
    } catch (e) {
      _showErrorDialog('An error occurred: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    setState(() => _isProcessing = false);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error'),
          ],
        ),
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
