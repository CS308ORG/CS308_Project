import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'basket_page.dart';
import 'product_detail.dart';

/// Helper to read an image URL from the product map.
String? getProductImageUrl(Map<String, dynamic> product) {
  final keys = [
    'imageUrl',
    'image_url',
    'image',
    'thumbnailUrl',
    'thumbnail_url',
  ];

  for (final key in keys) {
    final value = product[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  }
  return null;
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];

  // Search state
  String _searchQuery = '';
  String _appliedQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _suggestions = [];
  bool _showSuggestions = false;

  // Category filter state
  String? _selectedCategoryLabel;

  final Map<String, int> _categoryFilterIds = {
    'Electronics': 1,
    'Wear': 2,
    'Home Appliances': 3,
    'Computers': 4,
    'Audio': 5,
    'Phones': 6,
    'Accessories': 7,
    'Gaming': 8,
    'Sports': 9,
    'Books': 10,
  };

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        setState(() {
          _showSuggestions =
              _searchQuery.length >= 2 && _suggestions.isNotEmpty;
        });
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_searchFocusNode.hasFocus) {
            setState(() {
              _showSuggestions = false;
            });
          }
        });
      }
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
        _filteredProducts = List.from(products);
        _searchQuery = '';
        _appliedQuery = '';
        _searchController.clear();
        _suggestions = [];
        _showSuggestions = false;
        _selectedCategoryLabel = null;
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

      if (query.length < 2 || !_searchFocusNode.hasFocus) {
        _suggestions = [];
        _showSuggestions = false;
        return;
      }

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

  void _applySearch(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();

    setState(() {
      _searchQuery = query;
      _appliedQuery = query;
      _filteredProducts = _filterProducts();
      _showSuggestions = false;
    });

    FocusScope.of(context).unfocus();
  }

  /// Clears only the search bar and results, keeping the category if selected.
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _appliedQuery = '';
      _suggestions = [];
      _showSuggestions = false;
      // Recalculate filtered products (will fall back to category or all)
      _filteredProducts = _filterProducts();
    });
    FocusScope.of(context).unfocus();
  }

  void _onCategorySelected(String label) {
    setState(() {
      // Clear search first
      _searchController.clear();
      _searchQuery = '';
      _appliedQuery = '';
      _showSuggestions = false;

      // Toggle category
      if (_selectedCategoryLabel == label) {
        _selectedCategoryLabel = null;
      } else {
        _selectedCategoryLabel = label;
      }

      _filteredProducts = _filterProducts();
    });
  }

  void _resetToHome() {
    setState(() {
      _searchQuery = '';
      _appliedQuery = '';
      _searchController.clear();
      _selectedCategoryLabel = null;
      _filteredProducts = List.from(_products);
      _suggestions = [];
      _showSuggestions = false;
    });
    FocusScope.of(context).unfocus();
  }

  List<dynamic> _filterProducts() {
    List<dynamic> results = List.from(_products);

    final label = _selectedCategoryLabel;
    if (label != null) {
      final catId = _categoryFilterIds[label];
      if (catId != null) {
        results = results.where((product) {
          final multi = product['category_ids'];
          if (multi is List) {
            final ids = multi.map((e) => e.toString()).toList();
            if (ids.contains(catId.toString())) return true;
          }
          final single = product['category_id'];
          if (single != null && single.toString() == catId.toString())
            return true;
          return false;
        }).toList();
      }
    }

    final query = _appliedQuery.trim().toLowerCase();
    if (query.isNotEmpty) {
      results = results.where((product) {
        final name = (product['name'] ?? '').toString().toLowerCase();
        final description = (product['description'] ?? '')
            .toString()
            .toLowerCase();
        return name.contains(query) || description.contains(query);
      }).toList();
    }

    return results;
  }

  void _onSuggestionTap(Map<String, dynamic> product) {
    // REQUEST 1 & 3: Clear search and navigate
    _clearSearch();

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductDetail(product: product)),
    );
  }

  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
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
                        onChanged: _onSearchChanged,
                        onSubmitted: _applySearch,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[700],
                          ),
                          hintText: 'Search products by name or description',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7733),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 12,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.filter_list, color: Colors.white),
                  ),
                ],
              ),
              if (_showSuggestions && _suggestions.isNotEmpty)
                const SizedBox(height: 8),
              if (_showSuggestions && _suggestions.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 280),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 14,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final product =
                          _suggestions[index] as Map<String, dynamic>;
                      final imageUrl = getProductImageUrl(product);

                      // REQUEST 2: Mouse cursor change on suggestion hover
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: InkWell(
                          onTap: () => _onSuggestionTap(product),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF5E6),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Center(
                                    child: imageUrl != null
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            child: Image.network(
                                              imageUrl,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                            ),
                                          )
                                        : Icon(
                                            Icons.computer,
                                            size: 28,
                                            color: Colors.grey[500],
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'] ?? 'Product',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if ((product['description'] ?? '')
                                          .toString()
                                          .isNotEmpty)
                                        Text(
                                          product['description'],
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                if (product['price'] != null)
                                  Text(
                                    '${product['price']} ₺',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF7733),
                                    ),
                                  ),
                              ],
                            ),
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
    final bool isHomeState =
        _appliedQuery.isEmpty && _selectedCategoryLabel == null;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            _buildHeader(),
            _buildNavBar(),
            _buildSearchRow(),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF7733),
                      ),
                    )
                  : _error != null
                  ? _buildError()
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          if (isHomeState) ...[
                            _buildSaleBanner(),
                            _buildPopularSection(),
                            _buildPagination(),
                          ] else ...[
                            const SizedBox(height: 24),
                            _buildSearchResultsGrid(),
                          ],
                          const SizedBox(height: 40),
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
      color: const Color(0xFFFFF5E6),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _resetToHome,
              child: const Text(
                'CS308 STORE',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFF7733),
                ),
              ),
            ),
          ),
          Row(
            children: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart, size: 28),
                    color: const Color(0xFFFF7733),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => BasketPage()),
                      ).then((_) => setState(() {}));
                    },
                  ),
                  if (CartService().itemCount > 0)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Text(
                          '${CartService().itemCount}',
                          style: const TextStyle(
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
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7733),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Login'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => SignupScreen()),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF7733),
                  side: const BorderSide(color: Color(0xFFFF7733)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar() {
    final labels = [
      'Electronics',
      'Computers',
      'Phones',
      'Accessories',
      'Gaming',
      'Audio',
      'Books',
      'Wear',
      'Home Appliances',
      'Sports',
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: labels.map((label) => _navButton(label)).toList(),
          ),
        ),
      ),
    );
  }

  Widget _navButton(String text) {
    final bool isSelected = _selectedCategoryLabel == text;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _onCategorySelected(text),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF7733) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFF7733)),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFFFF7733),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSaleBanner() {
    if (_products.isEmpty) return const SizedBox.shrink();

    final featuredProduct = _products[0];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // REQUEST 1: Reset search (optional, but nice for clean state)
          _clearSearch();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetail(product: featuredProduct),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFFF7733),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
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
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 200,
                      width: 300,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.computer,
                          size: 100,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      featuredProduct['name'] ?? 'Featured Product',
                      style: const TextStyle(
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
      ),
    );
  }

  Widget _buildPopularSection() {
    final List<dynamic> productsToShow = _filteredProducts;

    if (productsToShow.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'No products found.',
          style: TextStyle(fontSize: 16, color: Colors.grey[700]),
        ),
      );
    }

    return Column(
      children: [
        const Text(
          'Popular This Week',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF7733),
          ),
        ),
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

  Widget _buildSearchResultsGrid() {
    final queryText = _searchController.text.trim();
    final bool hasSearchText = queryText.isNotEmpty;
    final bool hasCategory = _selectedCategoryLabel != null;

    String title = '';
    if (hasSearchText && hasCategory) {
      title = '${_selectedCategoryLabel!} results for "$queryText"';
    } else if (hasSearchText) {
      title = 'Search results for "$queryText"';
    } else if (hasCategory) {
      title = _selectedCategoryLabel!;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7733),
              ),
            ),
          if (title.isNotEmpty) const SizedBox(height: 12),
          Text(
            '${_filteredProducts.length} items found',
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.75,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _filteredProducts.length,
            itemBuilder: (context, index) {
              final product = _filteredProducts[index];
              return _buildProductCard(product);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final imageUrl = getProductImageUrl(product);

    // REQUEST 2: Mouse cursor change on product card hover
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // REQUEST 1: Reset search when viewing product detail
          _clearSearch();

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetail(product: product),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFF9F0),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
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
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Icon(
                            Icons.computer,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? 'Product',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '4.5 (120)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          CartService().addToCart(product);
                          setState(() {});

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${product['name']} added to cart!',
                              ),
                              backgroundColor: const Color(0xFFFF7733),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7733),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Add to Cart'),
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

  Widget _buildPagination() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
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
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {},
            child: const Text(
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
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('Error loading products'),
          const SizedBox(height: 8),
          Text(_error ?? ''),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadProducts,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7733),
            ),
            child: const Text('Retry'),
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
