import 'package:flutter/material.dart';
import 'dart:math'; // For min()
import '../services/api_service.dart';
import '../services/cart_service.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import 'basket_page.dart';

// ==========================================
// HELPER FUNCTIONS
// ==========================================

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

String getCategoryNames(Map<String, dynamic> product) {
  final Map<int, String> idToName = {
    1: 'Electronics',
    2: 'Wear',
    3: 'Home Appliances',
    4: 'Computers',
    5: 'Audio',
    6: 'Phones',
    7: 'Accessories',
    8: 'Gaming',
    9: 'Sports',
    10: 'Books',
  };

  List<String> names = [];
  if (product['category_ids'] is List) {
    for (var id in product['category_ids']) {
      if (idToName.containsKey(id)) names.add(idToName[id]!);
    }
  } else if (product['category_id'] != null) {
    int? id = int.tryParse(product['category_id'].toString());
    if (id != null && idToName.containsKey(id)) names.add(idToName[id]!);
  }

  if (names.isEmpty) return 'General';
  return names.toSet().join(', ');
}

// ==========================================
// STORE LAYOUT (Top Menu Wrapper)
// ==========================================
class StoreLayout extends StatefulWidget {
  final Widget body;
  final Function(String)? onSearchSubmitted;
  final Function(String)? onCategorySelected;

  // New callback for sorting [Requirement 3.5.2]
  final Function(String)? onSortSelected;

  final String? selectedCategory;

  const StoreLayout({
    Key? key,
    required this.body,
    this.onSearchSubmitted,
    this.onCategorySelected,
    this.onSortSelected,
    this.selectedCategory,
  }) : super(key: key);

  @override
  _StoreLayoutState createState() => _StoreLayoutState();
}

class _StoreLayoutState extends State<StoreLayout> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<dynamic> _allProducts = [];
  List<dynamic> _suggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadDataForSuggestions();
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        _onSearchChanged(_searchController.text);
      } else {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_searchFocusNode.hasFocus) {
            setState(() => _showSuggestions = false);
          }
        });
      }
    });
  }

  Future<void> _loadDataForSuggestions() async {
    try {
      final products = await _apiService.getProducts();
      if (mounted) setState(() => _allProducts = products);
    } catch (e) {}
  }

  void _onSearchChanged(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      if (query.length < 2) {
        _suggestions = [];
        _showSuggestions = false;
        return;
      }

      _suggestions = _allProducts
          .where((product) {
            final name = (product['name'] ?? '').toString().toLowerCase();
            return name.contains(query);
          })
          .take(6)
          .toList();

      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  // Helper to navigate to Product Detail from suggestions
  void _onSuggestionTap(Map<String, dynamic> product) {
    // Clear search before navigating
    _searchController.clear();
    setState(() => _showSuggestions = false);

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductDetail(product: product)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            _buildHeader(),
            _buildNavBar(),
            _buildSearchRow(),
            Expanded(child: widget.body),
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
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => HomeScreen()),
                  (route) => false,
                );
              },
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
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7733),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Login'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignupScreen()),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFF7733),
                  side: const BorderSide(color: Color(0xFFFF7733)),
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
            children: labels.map((label) {
              final isSelected = widget.selectedCategory == label;
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (widget.onCategorySelected != null) {
                      // Clear search if implemented in callback
                      _searchController.clear();
                      widget.onCategorySelected!(label);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              HomeScreen(initialCategory: label),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF7733)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFF7733)),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFFFF7733),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
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
                        onSubmitted: (val) {
                          if (widget.onSearchSubmitted != null) {
                            widget.onSearchSubmitted!(val);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    HomeScreen(initialSearch: val),
                              ),
                            );
                          }
                        },
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[700],
                          ),
                          hintText: widget.selectedCategory != null
                              ? 'Search in ${widget.selectedCategory}...'
                              : 'Search products...',
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

                  // [Requirement 3.5.2] Sort Dropdown Button
                  Container(
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
                    child: PopupMenuButton<String>(
                      icon: const Icon(Icons.filter_list, color: Colors.white),
                      tooltip: 'Sort Products',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (value) {
                        if (widget.onSortSelected != null) {
                          widget.onSortSelected!(value);
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'name_asc',
                              child: Text('Sort by name ↑'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'name_desc',
                              child: Text('Sort by name ↓'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'price_asc',
                              child: Text('Sort by price ↑'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'price_desc',
                              child: Text('Sort by price ↓'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'pop_asc',
                              child: Text('Sort by popularity ↑'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'pop_desc',
                              child: Text('Sort by popularity ↓'),
                            ),
                          ],
                    ),
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
                      final product = _suggestions[index];
                      final imageUrl = getProductImageUrl(product);
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: InkWell(
                          onTap: () =>
                              _onSuggestionTap(product), // Use helper method
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
                                        product['name'] ?? '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (product['description'] != null)
                                        Text(
                                          product['description'],
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (product['price'] != null)
                                  Text(
                                    '${product['price']} ₺',
                                    style: const TextStyle(
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
}

// ==========================================
// HOME SCREEN
// ==========================================
class HomeScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialSearch;

  HomeScreen({this.initialCategory, this.initialSearch});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();

  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];

  String _appliedQuery = '';
  String? _selectedCategoryLabel;
  String? _currentSortOption; // [Requirement 3.5.2] Sort State

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 18; // Default as per previous request
  final List<int> _itemsPerPageOptions = [
    9,
    18,
    24,
    48,
    72,
  ]; // [Requirement 3.4.1] Options

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
    if (widget.initialCategory != null)
      _selectedCategoryLabel = widget.initialCategory;
    if (widget.initialSearch != null) _appliedQuery = widget.initialSearch!;
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
        _filteredProducts = _filterProducts();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // [Requirement 3.5.2] Sorting Logic
  void _sortProducts(List<dynamic> list) {
    if (_currentSortOption == null) return;

    list.sort((a, b) {
      switch (_currentSortOption) {
        case 'name_asc':
          return (a['name'] ?? '').toString().compareTo(b['name'] ?? '');
        case 'name_desc':
          return (b['name'] ?? '').toString().compareTo(a['name'] ?? '');
        case 'price_asc':
          return (a['price'] ?? 0).compareTo(b['price'] ?? 0);
        case 'price_desc':
          return (b['price'] ?? 0).compareTo(a['price'] ?? 0);
        case 'pop_asc':
          // Popularity ascending (using ID as proxy for stability)
          return (a['product_id'] ?? 0).compareTo(b['product_id'] ?? 0);
        case 'pop_desc':
          // Popularity descending
          return (b['product_id'] ?? 0).compareTo(a['product_id'] ?? 0);
        default:
          return 0;
      }
    });
  }

  List<dynamic> _filterProducts() {
    List<dynamic> results = List.from(_products);

    // 1. Category Filter
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

    // 2. Search Filter
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

    // 3. [Requirement 3.5.2] Apply Sorting
    _sortProducts(results);

    _currentPage = 1;
    return results;
  }

  // [Requirement 3.5.2] Reset sort on Search
  void _handleSearch(String query) {
    setState(() {
      _appliedQuery = query;
      _currentSortOption = null; // Reset sort
      _filteredProducts = _filterProducts();
    });
  }

  // [Requirement 3.5.2] Reset sort on Category
  void _handleCategory(String label) {
    setState(() {
      _appliedQuery = '';
      _currentSortOption = null; // Reset sort
      if (_selectedCategoryLabel == label) {
        _selectedCategoryLabel = null;
      } else {
        _selectedCategoryLabel = label;
      }
      _filteredProducts = _filterProducts();
    });
  }

  // [Requirement 3.5.2] Handle Sort Selection
  void _handleSort(String option) {
    setState(() {
      _currentSortOption = option;
      _filteredProducts = _filterProducts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isHomeState =
        _appliedQuery.isEmpty && _selectedCategoryLabel == null;

    int totalItems = _filteredProducts.length;
    int totalPages = (totalItems / _itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
    if (_currentPage > totalPages) _currentPage = totalPages;

    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = min(startIndex + _itemsPerPage, totalItems);

    List<dynamic> currentProducts = [];
    if (startIndex < totalItems) {
      currentProducts = _filteredProducts.sublist(startIndex, endIndex);
    }

    return StoreLayout(
      onSearchSubmitted: _handleSearch,
      onCategorySelected: _handleCategory,
      onSortSelected: _handleSort, // Pass sort handler
      selectedCategory: _selectedCategoryLabel,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF7733)),
            )
          : _error != null
          ? _buildError()
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (isHomeState) _buildSaleBanner(),

                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isHomeState) ...[
                          Text(
                            _selectedCategoryLabel != null
                                ? '$_selectedCategoryLabel Results'
                                : 'Search Results for "$_appliedQuery"',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF7733),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else ...[
                          const Text(
                            'Popular This Week',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF7733),
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('$totalItems items found'),
                            Row(
                              children: [
                                const Text('Show: '),

                                // [Requirement 3.5.1] Luxurious Dropdown
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _itemsPerPage,
                                      icon: const Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      isDense: true,
                                      items: _itemsPerPageOptions.map((
                                        int value,
                                      ) {
                                        return DropdownMenuItem<int>(
                                          value: value,
                                          child: Text(value.toString()),
                                        );
                                      }).toList(),
                                      onChanged: (newValue) {
                                        setState(() {
                                          _itemsPerPage = newValue!;
                                          _currentPage = 1;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        currentProducts.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32),
                                  child: Text("No products found."),
                                ),
                              )
                            : GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      childAspectRatio: 0.75,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                itemCount: currentProducts.length,
                                itemBuilder: (context, index) {
                                  return _buildProductCard(
                                    currentProducts[index],
                                  );
                                },
                              ),
                      ],
                    ),
                  ),

                  _buildPaginationControls(totalPages),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final imageUrl = getProductImageUrl(product);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          // Reset search state locally before navigating to detail
          // so when user comes back, it's clean, OR just standard push
          _handleSearch("");
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

  Widget _buildPaginationControls(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Text(
              '<',
              style: TextStyle(
                fontSize: 24,
                color: Color(0xFFFF7733),
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _currentPage > 1
                ? () => setState(() => _currentPage--)
                : null,
          ),
          const SizedBox(width: 16),
          Text(
            'Page $_currentPage of $totalPages',
            style: const TextStyle(
              fontSize: 18,
              color: Color(0xFFFF7733),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 16),
          IconButton(
            icon: const Text(
              '>',
              style: TextStyle(
                fontSize: 24,
                color: Color(0xFFFF7733),
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: _currentPage < totalPages
                ? () => setState(() => _currentPage++)
                : null,
          ),
        ],
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
          // Clear search and sort before navigating
          _handleSearch("");
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
              // Inner Product Card in Banner
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
}

// ==========================================
// PRODUCT DETAIL PAGE
// ==========================================
class ProductDetail extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetail({Key? key, required this.product}) : super(key: key);

  @override
  _ProductDetailState createState() => _ProductDetailState();
}

class _ProductDetailState extends State<ProductDetail> {
  int _currentImageIndex = 0;
  final List<String> _productImages = ['Image 1', 'Image 2', 'Image 3'];

  @override
  Widget build(BuildContext context) {
    final imageUrl = getProductImageUrl(widget.product);

    final title = widget.product['name'] ?? 'Product Name';
    final price = widget.product['price'];
    final description = widget.product['description'] ?? 'No description.';
    final stock =
        widget.product['quantity_in_stock'] ??
        widget.product['stock_quantity'] ??
        0;
    final distributor =
        widget.product['distributor_info'] ?? 'Unknown Supplier';
    final categoryNames = getCategoryNames(widget.product);

    return StoreLayout(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Image Carousel
              Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFF7733), width: 3),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  height: 200,
                                  fit: BoxFit.contain,
                                )
                              : Icon(
                                  Icons.computer,
                                  size: 150,
                                  color: Colors.grey[400],
                                ),
                          const SizedBox(height: 16),
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            size: 40,
                            color: Color(0xFFFF7733),
                          ),
                          onPressed: () => setState(() {
                            if (_currentImageIndex > 0) _currentImageIndex--;
                          }),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_forward_ios,
                            size: 40,
                            color: Color(0xFFFF7733),
                          ),
                          onPressed: () => setState(() {
                            if (_currentImageIndex < _productImages.length - 1)
                              _currentImageIndex++;
                          }),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_productImages.length, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? const Color(0xFFFF7733)
                                  : Colors.grey[300],
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 2. Product Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      'ID:',
                      widget.product['id']?.toString() ??
                          widget.product['product_id']?.toString() ??
                          'N/A',
                    ),
                    _buildInfoRow('Category:', categoryNames),
                    _buildInfoRow('Price:', '${price ?? 0} ₺'),
                    _buildInfoRow('Stock:', '$stock units'),
                    _buildInfoRow('Distributor:', distributor),
                    _buildInfoRow(
                      'Serial No:',
                      widget.product['serial_number'] ?? 'N/A',
                    ),
                    _buildInfoRow('Information:', description),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 3. Rating Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Rating:',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < 4 ? Icons.star : Icons.star_border,
                          color: const Color(0xFFFF7733),
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. Add to Cart Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    CartService().addToCart(widget.product);
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Add to Cart',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 5. Reviews
              Column(
                children: [
                  _buildReviewCard('User1', 5, 'Great product!'),
                  const SizedBox(height: 16),
                  _buildReviewCard('User2', 4, 'Good value.'),
                ],
              ),

              const SizedBox(height: 24),

              // 6. Pagination
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    '< 1...20 >',
                    style: TextStyle(
                      fontSize: 20,
                      color: Color(0xFFFF7733),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: () {},
                    child: const Text(
                      'Load More',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFFFF7733),
                        decoration: TextDecoration.underline,
                      ),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFF7733),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Widget _buildReviewCard(String username, int rating, String comment) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7733),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Row(
                  children: List.generate(
                    5,
                    (index) => Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            comment,
            style: TextStyle(fontSize: 14, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }
}
