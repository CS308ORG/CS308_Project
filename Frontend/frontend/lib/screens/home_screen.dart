
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}



class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];

  // NEW: search state
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _suggestions = [];
  bool _showSuggestions = false;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _searchFocusNode.addListener(() {
      setState(() {
        _showSuggestions =
            _searchFocusNode.hasFocus &&
            _searchQuery.length >= 2 &&
            _suggestions.isNotEmpty;
      });
    });

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
        _filteredProducts = List.from(products); // NEW
        _searchQuery = '';
        _searchController.clear();
        _suggestions = [];
        _showSuggestions = false;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }



  void _onSearchChanged(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      _searchQuery = query;

      // No text → show all products, no suggestions
      if (query.isEmpty) {
        _filteredProducts = List.from(_products);
        _suggestions = [];
        _showSuggestions = false;
        return;
      }

      // Filter by name or description
      final matches = _products.where((product) {
        final name =
            (product['name'] ?? '').toString().toLowerCase();
        final description =
            (product['description'] ?? '').toString().toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();

      _filteredProducts = matches;

      // Only show dropdown if at least 2 chars AND we are in the box
      if (query.length >= 2 && _searchFocusNode.hasFocus) {
        _suggestions = matches.length > 6
            ? matches.sublist(0, 6)
            : matches;
        _showSuggestions = _suggestions.isNotEmpty;
      } else {
        _suggestions = [];
        _showSuggestions = false;
      }
    });
  }





  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: Color(0xFFFFF9F0), // soft cream, matches theme
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: TextField(
            onChanged: _onSearchChanged,
            style: TextStyle(fontSize: 16),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: Color(0xFFFF7733)),
              hintText: 'Search products by name or description',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ), 
      ),
    );
  }

  void _onSuggestionTap(Map<String, dynamic> product) {
    // Put selected name into the search box and filter list
    setState(() {
      _searchController.text = product['name'] ?? '';
      _onSearchChanged(_searchController.text);
      _showSuggestions = false;
    });

    FocusScope.of(context).unfocus();

    // Navigate to a very simple detail page (placeholder)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailPage(product: product),
      ),
    );
  }



  Widget _buildSearchRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            children: [
              // Search box
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: _onSearchChanged,
                  onSubmitted: (value) {
                    // When user presses ENTER:
                    _onSearchChanged(value);       // make sure filter uses final text
                    setState(() {
                      _showSuggestions = false;    // hide dropdown
                    });
                    FocusScope.of(context).unfocus(); // leave "writing" mode
                  },
                  decoration: InputDecoration(
                    hintText: 'Search products',
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12),
              // Filter / sort button (to the right of search box)
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Color(0xFFFF7733),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.filter_list, color: Colors.white),
              ),
            ],
          ),

          // Spacing before dropdown
          if (_showSuggestions && _suggestions.isNotEmpty)
            SizedBox(height: 8),

          // Suggestions dropdown
          if (_showSuggestions && _suggestions.isNotEmpty)
            Container(
              constraints: BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _suggestions.length,
                itemBuilder: (context, index) {
                  final product =
                      _suggestions[index] as Map<String, dynamic>;

                  return InkWell(
                    onTap: () => _onSuggestionTap(product),
                    child: Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          // Mini image (placeholder)
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Color(0xFFFFF5E6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.computer,
                              size: 22,
                              color: Colors.grey[500],
                            ),
                          ),
                          SizedBox(width: 12),
                          // Name + mini description
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product['name'] ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if ((product['description'] ?? '')
                                    .toString()
                                    .isNotEmpty)
                                  Text(
                                    product['description'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          SizedBox(width: 8),
                          // Price on the right
                          if (product['price'] != null)
                            Text(
                              '${product['price']} ₺',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF7733),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // Clicking anywhere outside → lose focus → dropdown closes
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            _buildHeader(),
            _buildNavBar(),
            _buildSearchRow(), // search + dropdown row

            Expanded(
              child: _loading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF7733),
                      ),
                    )
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
              ElevatedButton(
                onPressed: () {
                  // Navigate to Login Screen
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
                  // Navigate to Sign Up Screen
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _navButton('Electronics'),
          _navButton('Computers'),
          _navButton('Phones'),
          _navButton('Accessories'),
          _navButton('Gaming'),
          _navButton('Audio'),
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
    
    return Container(
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
    );
  }

  
  
  
  
  
  
  
  Widget _buildPopularSection() {
    // which list should we show?
    final List<dynamic> productsToShow =
        _searchQuery.isEmpty ? _products : _filteredProducts;

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
            itemCount: productsToShow.length,
            itemBuilder: (context, index) {
              return _buildProductCard(productsToShow[index]);
            },
          ),
        ),
      ],
    );
  }


  Widget _buildProductCard(Map<String, dynamic> product) {
    return Container(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added to cart!'),
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


  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

}







class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({Key? key, required this.product})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = product['name'] ?? 'Product';
    final description = product['description'] ?? '';
    final price = product['price'];

    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        backgroundColor: Color(0xFFFF7733),
        title: Text(name),
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 900),
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              // Left: big image placeholder
              Expanded(
                flex: 1,
                child: Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.computer,
                      size: 120,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 32),
              // Right: text / info
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: 24),
                    if (price != null)
                      Text(
                        '$price ₺',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7733),
                        ),
                      ),
                    SizedBox(height: 24),
                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Added to cart'),
                              backgroundColor: Color(0xFFFF7733),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFFFF7733),
                          foregroundColor: Colors.white,
                          padding:
                              EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text('Add to Cart'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}






/*
import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
              ElevatedButton(
                onPressed: () {},
                child: Text('Login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFF7733),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
              SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {},
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
    
    return Container(
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
    return Container(
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added to cart!'),
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

*/