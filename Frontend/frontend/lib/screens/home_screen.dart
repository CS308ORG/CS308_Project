import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

/// Helper to read an image URL from the product map.
/// This checks a few common field names so backend can choose one.
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
  String _searchQuery = ''; // what is currently typed
  String _appliedQuery = ''; // last query confirmed with ENTER
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _suggestions = [];
  bool _showSuggestions = false;

  // Category filter state
  String? _selectedCategoryLabel;

  /// Each category button uses EXACTLY ONE category_id
  /// (a product may have multiple category_ids in the DB, e.g. [1, 5])
  final Map<String, int> _categoryFilterIds = {
    'Electronics': 1,
    'Wear': 2, // Clothing
    'Home Appliances': 3,
    'Computers': 4,
    'Audio': 5,
    'Phones': 6, // Mobile
    'Accessories': 7, // Kitchen / misc
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

  /// LIVE typing → only update suggestions, NOT the main grid.
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

      // Filter products by name or description for suggestions (from ALL products)
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

  /// Apply full search to the main results page (ENTER pressed).
  void _applySearch(String rawQuery) {
    final query = rawQuery.trim().toLowerCase();

    setState(() {
      _searchQuery = query;
      _appliedQuery = query;
      _filteredProducts = _filterProducts(); // apply search + category
      _showSuggestions = false;
    });

    // Leave "writing mode" after confirming search
    FocusScope.of(context).unfocus();
  }

  /// Called when a category button is clicked.
  /// NOW behaves like a "results state", not a toggle on/off.
  void _onCategorySelected(String label) {
    setState(() {
      _selectedCategoryLabel = label; // no more toggling off
      _filteredProducts = _filterProducts(); // show that category's results
    });
  }

  /// Resets everything to "home state" when clicking the logo.
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

  /// Combine category filter + applied search text.
  List<dynamic> _filterProducts() {
    List<dynamic> results = List.from(_products);

    // 1) Category filter (if any)
    final label = _selectedCategoryLabel;
    if (label != null) {
      final catId = _categoryFilterIds[label];
      if (catId != null) {
        results = results.where((product) {
          // support both category_id (single) and category_ids (list)
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

    // 2) Applied search query (only when ENTER was pressed)
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

  /// When a suggestion is clicked in the dropdown.
  void _onSuggestionTap(Map<String, dynamic> product) {
    final selectedName = (product['name'] ?? '').toString();

    // Put the selected name into the search box
    _searchController.text = selectedName;

    // Update suggestion state for consistency
    _onSearchChanged(selectedName);

    // Commit the search (filters results)
    _applySearch(selectedName);

    // Navigate to the product detail page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailPage(product: product),
      ),
    );
  }

  /// Search row: elegant white box + filter button + dropdown underneath.
  Widget _buildSearchRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: ConstrainedBox(
          // Slightly wider than nav buttons group
          constraints: const BoxConstraints(maxWidth: 980),
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
                  // Sort / filter button
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

              // Spacing before dropdown
              if (_showSuggestions && _suggestions.isNotEmpty)
                const SizedBox(height: 8),

              // Suggestions dropdown – same look as before
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

                      return InkWell(
                        onTap: () => _onSuggestionTap(product),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              // Mini image or placeholder
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
                              // Title + mini description
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
          // Clicking anywhere outside → lose focus → dropdown closes
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
                            // HOME STATE: hero + popular + pagination
                            _buildSaleBanner(),
                            _buildPopularSection(),
                            _buildPagination(),
                          ] else ...[
                            // RESULTS STATE: either search or category (or both)
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
          // Logo with pointer cursor + click → go home
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

  /// Category bar: wraps into multiple centered lines on small screens.
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

    return Container(
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
    );
  }

  /// On home, uses _filteredProducts (all products there).
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

  /// Results grid: used for both search results and category-only results.
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

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9F0),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
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
                    : Icon(Icons.computer, size: 80, color: Colors.grey[400]),
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
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Added to cart!'),
                          backgroundColor: Color(0xFFFF7733),
                          duration: Duration(seconds: 1),
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

class ProductDetailPage extends StatelessWidget {
  final Map<String, dynamic> product;

  const ProductDetailPage({Key? key, required this.product}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = product['name'] ?? 'Product';
    final description = product['description'] ?? '';
    final price = product['price'];
    final imageUrl = getProductImageUrl(product);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7733),
        title: Text(name),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              // Left: big image
              Expanded(
                flex: 1,
                child: Container(
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Icon(
                            Icons.computer,
                            size: 120,
                            color: Colors.grey[400],
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 32),
              // Right: text / info
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      description,
                      style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                    ),
                    const SizedBox(height: 24),
                    if (price != null)
                      Text(
                        '$price ₺',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7733),
                        ),
                      ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 180,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Added to cart'),
                              backgroundColor: Color(0xFFFF7733),
                              duration: Duration(seconds: 1),
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
}
