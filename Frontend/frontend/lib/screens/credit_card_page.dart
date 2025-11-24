import 'package:flutter/material.dart';
import 'home_screen.dart';

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
                      _showSuccessDialog();
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payment Successful!'),
        content: Text('Your order has been placed successfully.'),
        actions: [
          TextButton(
            onPressed: () {
              // Go back to home screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => HomeScreen()),
                (route) => false,
              );
            },
            child: Text('OK', style: TextStyle(color: Color(0xFFFF7733))),
          ),
        ],
      ),
    );
  }
}
