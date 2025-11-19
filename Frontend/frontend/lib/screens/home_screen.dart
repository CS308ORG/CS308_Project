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

  // Search state
  String _searchQuery = ''; // what is in the TextField right now
  String _appliedQuery = ''; // last query that was confirmed with ENTER
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
        _filteredProducts = List.from(products); // default grid contents
        _searchQuery = '';
        _appliedQuery = '';
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

  // LIVE typing → only update suggestions
  void _onSearchChanged(String value) {
    final query = value.trim().toLowerCase();

    setState(() {
      _searchQuery = query;

      // If empty or too short → no suggestions
      if (query.length < 2 || !_searchFocusNode.hasFocus) {
        _suggestions = [];
        _showSuggestions = false;
        return;
      }

      // Filter products by name or description for suggestions
      final matches = _products.where((product) {
        final name = (product['name'] ?? '').toString().toLowerCase();
        final description = (product['description'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();

      _suggestions = matches.length > 6 ? matches.sublist(0, 6) : matches;
      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  // ENTER → apply search to the main results page
  void _applySearch(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();

    setState(() {
      _searchQuery = query;
      _appliedQuery = query;

      if (query.isEmpty) {
        _filteredProducts = List.from(_products);
      } else {
        _filteredProducts = _products.where((product) {
          final name = (product['name'] ?? '').toString().toLowerCase();
          final description = (product['description'] ?? '')
              .toString()
              .toLowerCase();
          return name.contains(query) || description.contains(query);
        }).toList();
      }

      _showSuggestions = false;
    });

    // Leave "writing mode" after confirming search
    FocusScope.of(context).unfocus();
  }

  // Old compact search bar (not used anymore, safe to delete if you want)
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 600),
          decoration: BoxDecoration(
            color: Color(0xFFFFF9F0),
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
    final selectedName = (product['name'] ?? '').toString();

    // Put the selected name into the search box
    _searchController.text = selectedName;

    // Update suggestions state
    _onSearchChanged(selectedName);

    // Commit the search (filters the grid based on this product name)
    _applySearch(selectedName);

    // Navigate to the product detail page (placeholder)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
  }

  // Search row + dropdown (with OLD visual style for suggestions)
  Widget _buildSearchRow() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 980), // slightly wider than nav
          child: Column(
            children: [
              Row(
                children: [
                  // Elegant white search box
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                        border: Border.all(color: Colors.black12, width: 0.6),
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        onChanged: _onSearchChanged, // live suggestions
                        onSubmitted: _applySearch, // apply search on ENTER
                        style: TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[700],
                          ),
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
                  SizedBox(width: 12),
                  // Sort / filter button
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Color(0xFFFF7733),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Icon(Icons.filter_list, color: Colors.white),
                  ),
                ],
              ),

              // Spacing before dropdown
              if (_showSuggestions && _suggestions.isNotEmpty)
                SizedBox(height: 8),

              // Suggestions dropdown – VISUAL STYLE FROM OLD CODE
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
                      final price = product['price'];

                      return InkWell(
                        onTap: () => _onSuggestionTap(product),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
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
                              if (price != null)
                                Text(
                                  '$price ₺',
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
        ),
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
                          if (_appliedQuery.isEmpty) ...[
                            // HOME STATE: hero + popular + pagination
                            _buildSaleBanner(),
                            _buildPopularSection(),
                            _buildPagination(),
                          ] else ...[
                            // SEARCH RESULTS STATE: ONLY relevant items
                            SizedBox(height: 24),
                            _buildSearchResultsGrid(),
                          ],
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
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 920), // nav width
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
        ),
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
                  child: Icon(
                    Icons.computer,
                    size: 100,
                    color: Colors.grey[400],
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  featuredProduct['name'] ?? 'Featured Product',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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

  /// "Popular This Week" section for the home state
  Widget _buildPopularSection() {
    if (_products.isEmpty) return SizedBox.shrink();

    final List<dynamic> productsToShow = _products;

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

  /// Search results grid – only relevant items, no "Popular" title
  Widget _buildSearchResultsGrid() {
    final List<dynamic> productsToShow = _filteredProducts;

    if (productsToShow.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: Text(
          'No products found for "${_appliedQuery}".',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w500,
            color: Colors.grey[800],
          ),
        ),
      );
    }

    return Padding(
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
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final String name = product['name'] ?? 'Product';
    final String description = (product['description'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFFFF9F0),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
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
                  name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (description.isNotEmpty) ...[
                  SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
                SizedBox(
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
              Text(
                '< ',
                style: TextStyle(fontSize: 24, color: Color(0xFFFF7733)),
              ),
              Text(
                '1...200',
                style: TextStyle(fontSize: 24, color: Color(0xFFFF7733)),
              ),
              Text(
                ' >',
                style: TextStyle(fontSize: 24, color: Color(0xFFFF7733)),
              ),
            ],
          ),
          SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            child: Text(
              'Load More',
              style: TextStyle(fontSize: 18, color: Color(0xFFFF7733)),
            ),
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
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF7733)),
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

  const ProductDetailPage({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = product['name'] ?? 'Product';
    final description = product['description'] ?? '';
    final price = product['price'];

    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(backgroundColor: Color(0xFFFF7733), title: Text(name)),
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
                      style: TextStyle(fontSize: 16, color: Colors.grey[800]),
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
                          padding: EdgeInsets.symmetric(vertical: 12),
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
