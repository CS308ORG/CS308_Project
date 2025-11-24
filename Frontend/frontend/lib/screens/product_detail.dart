import 'package:flutter/material.dart';

class ProductDetail extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetail({required this.product});

  @override
  _ProductDetailState createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> {
  int _currentImageIndex = 0;
  final List<String> _productImages = [
    'Image 1',
    'Image 2',
    'Image 3',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        title: Text('Product Detail'),
        backgroundColor: Color(0xFFFF7733),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageCarousel(),
              SizedBox(height: 24),
              _buildProductInfo(),
              SizedBox(height: 24),
              _buildRatingSection(),
              SizedBox(height: 24),
              _buildReviews(),
              SizedBox(height: 24),
              _buildPagination(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageCarousel() {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFFF7733), width: 3),
      ),
      child: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.computer, size: 150, color: Colors.grey[400]),
                SizedBox(height: 16),
                Text(
                  widget.product['name'] ?? 'Product Name',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Left Arrow
          Positioned(
            left: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios, size: 40, color: Color(0xFFFF7733)),
                onPressed: () {
                  setState(() {
                    if (_currentImageIndex > 0) _currentImageIndex--;
                  });
                },
              ),
            ),
          ),

          // Right Arrow
          Positioned(
            right: 16,
            top: 0,
            bottom: 0,
            child: Center(
              child: IconButton(
                icon: Icon(Icons.arrow_forward_ios, size: 40, color: Color(0xFFFF7733)),
                onPressed: () {
                  setState(() {
                    if (_currentImageIndex < _productImages.length - 1) _currentImageIndex++;
                  });
                },
              ),
            ),
          ),

          // Indicator Dots
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_productImages.length, (index) {
                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentImageIndex == index
                        ? Color(0xFFFF7733)
                        : Colors.grey[300],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductInfo() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          _buildInfoRow('ID:', widget.product['id']?.toString() ?? 'N/A'),
          _buildInfoRow('Serial No:', 'SN123456789'),
          _buildInfoRow('Stock:', '25 units'),
          _buildInfoRow('Price:', '\$${widget.product['price'] ?? '0.00'}'),
          _buildInfoRow('Guarantee:', '2 years'),
          _buildInfoRow('Distributor:', 'Tech Supplies Inc.'),
          _buildInfoRow('Information:', widget.product['description'] ?? 'No description available'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Color(0xFFFF7733),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text(
            'Rating:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 16),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < 3 ? Icons.star : Icons.star_border,
                color: Color(0xFFFF7733),
                size: 24,
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildReviews() {
    return Column(
      children: [
        _buildReviewCard('ejey', 3, 'I really enjoyed this product.'),
        SizedBox(height: 16),
        _buildReviewCard('ejey', 3, 'I really enjoyed this product.'),
        SizedBox(height: 16),
        _buildReviewCard('ejey', 3, 'I really enjoyed this product.'),
        SizedBox(height: 16),
        _buildReviewCard('ejey', 3, 'I really enjoyed this product.'),
      ],
    );
  }

  Widget _buildReviewCard(String username, int rating, String comment) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Color(0xFFFF7733),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 16),
                Row(
                  children: List.generate(5, (index) {
                    return Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.white,
                      size: 16,
                    );
                  }),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            comment,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '< 1...20 >',
          style: TextStyle(
            fontSize: 20,
            color: Color(0xFFFF7733),
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(width: 16),
        TextButton(
          onPressed: () {},
          child: Text(
            'Load More',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFFFF7733),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }
}