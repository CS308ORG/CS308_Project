import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'basket_page.dart';
import 'product_detail.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _products = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final products = await _apiService.getProducts();
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      body: Column(
        children: [
          _buildHeader(),
          _buildNavBar(),
          
          Expanded(
            child: _loading
                ? Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)))
                : _error != null
                    ? _buildError()
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            _buildSaleBanner(),
                            _buildPopularSection(),
                            _buildPagination(),
                            SizedBox(height: 40),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Color(0xFFFFF5E6),
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'CS308 STORE',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF7733),
            ),
          ),
          
          Row(
            children: [
              // Basket Button with Badge
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.shopping_cart, size: 28),
                    color: Color(0xFFFF7733),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => BasketPage()),
                      ).then((_) => setState(() {})); // Refresh when returning
                    },
                  ),
                  if (CartService().itemCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          '${CartService().itemCount}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: 16),

              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                child: Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF7733),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignupScreen()),
                  );
                },
                child: Text('Sign Up'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Color(0xFFFF7733),
                  side: BorderSide(color: Color(0xFFFF7733)),
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFFF7733),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.search, color: Colors.white),
          ),
          
          Spacer(),
          
          _navButton('Electronics'),
          _navButton('Computers'),
          _navButton('Phones'),
          _navButton('Accessories'),
          _navButton('Gaming'),
          _navButton('Audio'),
          
          Spacer(),
          
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Color(0xFFFF7733),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.filter_list, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _navButton(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Color(0xFFFF7733),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          text,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildSaleBanner() {
    if (_products.isEmpty) return SizedBox.shrink();
    
    final featuredProduct = _products[0];
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetail(product: featuredProduct),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.all(24),
        padding: EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Color(0xFFFF7733),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('🔥', style: TextStyle(fontSize: 40)),
                SizedBox(width: 20),
                Text(
                  'SALE',
                  style: TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 8,
                  ),
                ),
                SizedBox(width: 20),
                Text('🔥', style: TextStyle(fontSize: 40)),
              ],
            ),
            
            SizedBox(height: 32),
            
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Container(
                    height: 200,
                    width: 300,
                    color: Colors.grey[200],
                    child: Icon(Icons.computer, size: 100, color: Colors.grey[400]),
                  ),
                  SizedBox(height: 16),
                  Text(
                    featuredProduct['name'] ?? 'Featured Product',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    featuredProduct['description'] ?? '',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularSection() {
    return Column(
      children: [
        Text(
          'Popular This Week',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF7733),
          ),
        ),
        
        SizedBox(height: 32),
        
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              return _buildProductCard(_products[index]);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetail(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFFFFF9F0),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                margin: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(Icons.computer, size: 80, color: Colors.grey[400]),
                ),
              ),
            ),
            
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Product',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star, color: Colors.orange, size: 16),
                      SizedBox(width: 4),
                      Text(
                        '4.5 (120)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Add product to cart
                        CartService().addToCart(product);
                        
                        // Update UI to show new cart count
                        setState(() {});
                        
                        // Show confirmation
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${product['name']} added to cart!'),
                            backgroundColor: Color(0xFFFF7733),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                      child: Text('Add to Cart'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFF7733),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12),
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

  Widget _buildPagination() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('< ', style: TextStyle(fontSize: 24, color: Color(0xFFFF7733))),
              Text('1...200', style: TextStyle(fontSize: 24, color: Color(0xFFFF7733))),
              Text(' >', style: TextStyle(fontSize: 24, color: Color(0xFFFF7733))),
            ],
          ),
          SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            child: Text('Load More', style: TextStyle(fontSize: 18, color: Color(0xFFFF7733))),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text('Error loading products'),
          SizedBox(height: 8),
          Text(_error ?? ''),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadProducts,
            child: Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF7733),
            ),
          ),
        ],
      ),
    );
  }
}