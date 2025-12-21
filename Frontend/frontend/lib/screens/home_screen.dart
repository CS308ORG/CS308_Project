import 'package:flutter/material.dart';
import 'dart:math'; // For min()
import '../services/api_service.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';
// Uses AuthService for backend login state
import 'login_screen.dart';
import 'signup_screen.dart';
import 'basket_page.dart';
import 'order_history_page.dart'; // Order History
import 'product_detail.dart';
import 'product_manager_page.dart';
import 'review_moderation_page.dart';
import 'admin_home.dart';
import 'customer_home.dart';
// Product Detail Page

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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<dynamic> _allProducts = [];
  List<dynamic> _suggestions = [];
  bool _showSuggestions = false;
  Set<String> _hoveredCategories = {};

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

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
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
            final description = (product['description'] ?? '')
                .toString()
                .toLowerCase();
            final model = (product['model'] ?? '').toString().toLowerCase();
            final serialNumber = (product['serial_number'] ?? '')
                .toString()
                .toLowerCase();
            final categoryNames = getCategoryNames(product).toLowerCase();

            return name.contains(query) ||
                description.contains(query) ||
                model.contains(query) ||
                serialNumber.contains(query) ||
                categoryNames.contains(query);
          })
          .take(6)
          .toList();

      _showSuggestions = _suggestions.isNotEmpty;
    });
  }

  void _onSuggestionTap(Map<String, dynamic> product) {
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
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFF5E6),
      drawer: _buildDrawer(),
      body: Column(
        children: [
          _buildHeader(),
          _buildNavBar(),
            _buildSearchRow(),
          Expanded(
            child: GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              behavior: HitTestBehavior.opaque,
              child: widget.body,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final authService = AuthService();
    final isLoggedIn = authService.isLoggedIn;
    final userRole = authService.userRole;
    final userName = authService.userName;

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF5E6),
              Color(0xFFFFE8D6),
              Color(0xFFFFF5E6),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFFFF7733),
                      Color(0xFFFFA366),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.shopping_bag_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All is Here',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (isLoggedIn)
                            Text(
                              userName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Menu Items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _buildDrawerItem(
                      icon: Icons.home_rounded,
                      title: 'Home',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (context) => HomeScreen()),
                          (route) => false,
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.shopping_cart_rounded,
                      title: 'Shopping Cart',
                      badge: CartService().itemCount > 0 ? CartService().itemCount : null,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => BasketPage()),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.history_rounded,
                      title: 'Order History',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => OrderHistoryPage()),
                        );
                      },
                    ),
                    Divider(height: 32),
                    if (isLoggedIn) ...[
                      if (userRole == 'product_manager')
                        _buildDrawerItem(
                          icon: Icons.local_shipping_rounded,
                          title: 'Delivery Queue',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ProductManagerPage()),
                            );
                          },
                        ),
                      if (userRole == 'product_manager')
                        _buildDrawerItem(
                          icon: Icons.reviews_rounded,
                          title: 'Review Moderation',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => ReviewModerationPage()),
                            );
                          },
                        ),
                      if (userRole == 'admin')
                        _buildDrawerItem(
                          icon: Icons.admin_panel_settings_rounded,
                          title: 'Admin Dashboard',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => AdminHome(
                                username: userName,
                                role: userRole,
                              )),
                            );
                          },
                        ),
                      if (userRole == 'customer')
                        _buildDrawerItem(
                          icon: Icons.person_rounded,
                          title: 'Customer Dashboard',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => CustomerHome(
                                username: userName,
                                role: userRole,
                              )),
                            );
                          },
                        ),
                      Divider(height: 32),
                      _buildDrawerItem(
                        icon: Icons.logout_rounded,
                        title: 'Logout',
                        onTap: () async {
                          Navigator.pop(context);
                          await authService.logout();
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (context) => HomeScreen()),
                            (route) => false,
                          );
                        },
                      ),
                    ] else ...[
                      _buildDrawerItem(
                        icon: Icons.login_rounded,
                        title: 'Login',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => LoginScreen()),
                          );
                        },
                      ),
                      _buildDrawerItem(
                        icon: Icons.person_add_rounded,
                        title: 'Sign Up',
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SignupScreen()),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    int? badge,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Color(0xFFFF7733).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: Color(0xFFFF7733),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
        ),
      ),
      trailing: badge != null && badge > 0
          ? Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge.toString(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
            ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _buildHeader() {
    final authService = AuthService();
    final isLoggedIn = authService.isLoggedIn;
    String displayName = authService.userName;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFF8F0),
            const Color(0xFFFFF5E6),
            const Color(0xFFFFF0E0),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Navigation Icon
              IconButton(
                icon: const Icon(
                  Icons.menu_rounded,
                  size: 28,
                  color: Color(0xFFFF7733),
                ),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                tooltip: 'Menu',
              ),
              const SizedBox(width: 8),
              // Logo
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => HomeScreen()),
                      (route) => false,
                    );
                  },
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        const Color(0xFFFF7733),
                        const Color(0xFFFFA366),
                      ],
                    ).createShader(bounds),
                    child: const Text(
                      'All is Here',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Row(
            children: [
              // 1. Name (Orange) - only if logged in
              if (isLoggedIn) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        color: Color(0xFFFF7733),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 16),
              ],

              // 2. Cart Logo
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
                        key: ValueKey(CartService().itemCount),
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
              SizedBox(width: 16),

              // 3. Auth State Toggle
              if (!isLoggedIn) ...[
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => LoginScreen()),
                    ).then((_) => setState(() {}));
                    // Refresh header after returning from login
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7733),
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: const Color(0xFFFF7733).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                    side: const BorderSide(color: Color(0xFFFF7733), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Sign Up'),
                ),
              ] else ...[
                //ADDED PM
                // 4. Profile Picture & Dropdown
                PopupMenuButton<String>(
                  icon: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF7733),
                          const Color(0xFFFFA366),
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7733).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.transparent,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                  onSelected: (value) async {
                    if (value == 'orders') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => OrderHistoryPage(),
                        ),
                      );
                    } else if (value == 'delivery') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductManagerPage(),
                        ),
                      );
                    } else if (value == 'reviews') {
                      // FIXED: Added navigation handler for reviews
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReviewModerationPage(),
                        ),
                      );
                    } else if (value == 'info') {
                      // Navigate to Info (Placeholder)
                    } else if (value == 'logout') {
                      await AuthService()
                          .logout(); // clears current session + cart view
                      setState(() {});
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => HomeScreen()),
                        (route) => false,
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) {
                    final role = AuthService().userRole;
                    return <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(
                        value: 'info',
                        child: Text('My Information'),
                      ),
                      const PopupMenuItem<String>(
                        value: 'orders',
                        child: Text('My Orders'),
                      ),
                      // Show Product Manager options only for product managers
                      if (role == 'product_manager') ...[
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'delivery',
                          child: Row(
                            children: [
                              Icon(
                                Icons.local_shipping,
                                size: 18,
                                color: Colors.blue,
                              ),
                              SizedBox(width: 8),
                              Text('Delivery Queue'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'reviews',
                          child: Row(
                            children: [
                              Icon(
                                Icons.rate_review,
                                size: 18,
                                color: Colors.orange,
                              ),
                              SizedBox(width: 8),
                              Text('Review Moderation'),
                            ],
                          ),
                        ),
                      ],
                      const PopupMenuDivider(),
                      const PopupMenuItem<String>(
                        value: 'logout',
                        child: Text(
                          'Log Out',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ];
                  },
                ),
              ],
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
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
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
              final isHovered = _hoveredCategories.contains(label);
              return MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) {
                  setState(() {
                    _hoveredCategories.add(label);
                  });
                },
                onExit: (_) {
                  setState(() {
                    _hoveredCategories.remove(label);
                  });
                },
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (widget.onCategorySelected != null) {
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
                    borderRadius: BorderRadius.circular(24),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      padding: EdgeInsets.symmetric(
                        horizontal: isHovered || isSelected ? 26 : 20,
                        vertical: isHovered || isSelected ? 12 : 8,
                      ),
                      decoration: BoxDecoration(
                        gradient: (isSelected || isHovered)
                            ? LinearGradient(
                                colors: [
                                  const Color(0xFFFF7733),
                                  const Color(0xFFFFA366),
                                ],
                              )
                            : null,
                        color: (isSelected || isHovered) ? null : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFF7733),
                          width: (isSelected || isHovered) ? 0 : 1.5,
                        ),
                        boxShadow: (isSelected || isHovered)
                            ? [
                                BoxShadow(
                                  color: const Color(0xFFFF7733).withOpacity(
                                    isHovered ? 0.5 : 0.3,
                                  ),
                                  blurRadius: isHovered ? 15 : 8,
                                  offset: Offset(0, isHovered ? 8 : 4),
                                  spreadRadius: isHovered ? 3 : 0,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        label,
                        style: TextStyle(
                          color: (isSelected || isHovered)
                              ? Colors.white
                              : const Color(0xFFFF7733),
                          fontWeight: FontWeight.w600,
                          fontSize: isHovered || isSelected ? 15 : 13,
                        ),
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
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: const Color(0xFFFF7733).withOpacity(0.05),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFFFF7733).withOpacity(0.2),
                          width: 1,
                        ),
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
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFFF7733),
                          const Color(0xFFFFA366),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7733).withOpacity(0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
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
                                              loadingBuilder:
                                                  (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress == null)
                                                      return child;
                                                    return const SizedBox(
                                                      width: 56,
                                                      height: 56,
                                                      child: Center(
                                                        child: SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child:
                                                              CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                color: Color(
                                                                  0xFFFF7733,
                                                                ),
                                                              ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                    return Icon(
                                                      Icons.broken_image,
                                                      size: 28,
                                                      color: Colors.grey[500],
                                                    );
                                                  },
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
// HOME SCREEN (Main Grid)
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
  String? _currentSortOption;

  int _currentPage = 1;
  int _itemsPerPage = 18;
  final List<int> _itemsPerPageOptions = [9, 18, 24, 48, 72];
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

  // Helper function to get average rating for popularity sorting
  double _getAverageRating(Map<String, dynamic> product) {
    final averageRating = product['average_rating'];
    if (averageRating != null && averageRating is num) {
      return averageRating.toDouble();
    }
    return 0.0;
  }

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
          // Sort by average_rating (yıldız ortalaması) ascending
          final ratingA = _getAverageRating(a);
          final ratingB = _getAverageRating(b);
          return ratingA.compareTo(ratingB);
        case 'pop_desc':
          // Sort by average_rating (yıldız ortalaması) descending
          final ratingA = _getAverageRating(a);
          final ratingB = _getAverageRating(b);
          return ratingB.compareTo(ratingA);
        default:
          return 0;
      }
    });
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
        final model = (product['model'] ?? '').toString().toLowerCase();
        final serialNumber = (product['serial_number'] ?? '')
            .toString()
            .toLowerCase();
        final categoryNames = getCategoryNames(product).toLowerCase();
        final distributor = (product['distributor_info'] ?? '')
            .toString()
            .toLowerCase();

        return name.contains(query) ||
            description.contains(query) ||
            model.contains(query) ||
            serialNumber.contains(query) ||
            categoryNames.contains(query) ||
            distributor.contains(query);
      }).toList();
    }

    _sortProducts(results);
    _currentPage = 1;
    return results;
  }

  void _handleSearch(String query) {
    setState(() {
      _appliedQuery = query;
      _currentSortOption = null;
      _filteredProducts = _filterProducts();
    });
  }

  void _handleCategory(String label) {
    setState(() {
      _appliedQuery = '';
      _currentSortOption = null;
      if (_selectedCategoryLabel == label) {
        _selectedCategoryLabel = null;
      } else {
        _selectedCategoryLabel = label;
      }
      _filteredProducts = _filterProducts();
    });
  }

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
      onSortSelected: _handleSort,
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

                  // Wrapper for Margins - 1080 MaxWidth
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Padding(
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
                                            color: Colors.black.withOpacity(
                                              0.05,
                                            ),
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
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          childAspectRatio: 0.68,
                                          crossAxisSpacing: 24,
                                          mainAxisSpacing: 24,
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
    final int stock = product['quantity_in_stock'] ?? 0;
    final bool isOutOfStock = stock == 0;
    final rating = product['average_rating'] ?? 0.0;
    final price = product['price'] ?? 0;

    // Calculate max allowed (Lowest of stock or 10)
    final int maxAllowed = min(stock, 10);

    // Check quantity in cart
    final cartItem = CartService().items.firstWhere(
      (item) =>
          (item['id'] ?? item['product_id']).toString() ==
          (product['product_id'] ?? product['id']).toString(),
      orElse: () => {},
    );
    final int currentCartQty = cartItem['quantity'] ?? 0;

    // Disable if cart quantity reached max allowed
    final bool canAddToCart = currentCartQty < maxAllowed;

    return _ProductCardWidget(
      product: product,
      imageUrl: imageUrl,
      isOutOfStock: isOutOfStock,
      canAddToCart: canAddToCart,
      stock: stock,
      rating: rating,
      price: price,
      onTap: () {
        _handleSearch("");
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetail(product: product),
          ),
        );
      },
      onAddToCart: () {
        // This will be called multiple times based on quantity
        CartService().addToCart(product);
        setState(() {});
      },
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _currentPage > 1
                        ? Color(0xFFFF7733).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentPage > 1
                          ? Color(0xFFFF7733).withOpacity(0.3)
                          : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        color: _currentPage > 1
                            ? Color(0xFFFF7733)
                            : Colors.grey[400],
                        size: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _currentPage > 1
                              ? Color(0xFFFF7733)
                              : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            
            // Page Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF7733),
                    Color(0xFFFFA366),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF7733).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_currentPage',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7733),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'of',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalPages',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            
            // Next Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _currentPage < totalPages
                        ? Color(0xFFFF7733).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentPage < totalPages
                          ? Color(0xFFFF7733).withOpacity(0.3)
                          : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _currentPage < totalPages
                              ? Color(0xFFFF7733)
                              : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _currentPage < totalPages
                            ? Color(0xFFFF7733)
                            : Colors.grey[400],
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleBanner() {
    if (_products.isEmpty) return const SizedBox.shrink();
    final featuredProduct = _products[0];
    final imageUrl = getProductImageUrl(featuredProduct);
    final price = featuredProduct['price'] ?? 0;
    final rating = featuredProduct['average_rating'] ?? 0.0;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _handleSearch("");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetail(product: featuredProduct),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF7733),
                const Color(0xFFFFA366),
                const Color(0xFFFF5500),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7733).withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(40),
                child: Row(
                  children: [
                    // Left side - Product info
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sale badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'FLASH SALE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF7733),
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Product name
                          Text(
                            featuredProduct['name'] ?? 'Featured Product',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Description
                          if (featuredProduct['description'] != null)
                            Text(
                              featuredProduct['description'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 24),
                          // Rating and price row
                          Row(
                            children: [
                              // Rating
                              if (rating > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              // Price
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$price ₺',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF7733),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // CTA Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _handleSearch("");
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProductDetail(product: featuredProduct),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'Shop Now',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF7733),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Color(0xFFFF7733),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Right side - Product image
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 400,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: const Color(0xFFFF7733),
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[100],
                                      child: Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 80,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[100],
                                  child: Center(
                                    child: Icon(
                                      Icons.shopping_bag,
                                      size: 100,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                        ),
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

class _ProductCardWidget extends StatefulWidget {
  final Map<String, dynamic> product;
  final String? imageUrl;
  final bool isOutOfStock;
  final bool canAddToCart;
  final int stock;
  final double rating;
  final num price;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const _ProductCardWidget({
    required this.product,
    required this.imageUrl,
    required this.isOutOfStock,
    required this.canAddToCart,
    required this.stock,
    required this.rating,
    required this.price,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  _ProductCardWidgetState createState() => _ProductCardWidgetState();
}

class _ProductCardWidgetState extends State<_ProductCardWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.isOutOfStock
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(24),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF7733).withOpacity(0.15),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF7733).withOpacity(0.05),
                        blurRadius: 25,
                        offset: const Offset(0, 10),
                      ),
                    ],
            ),
            transform: Matrix4.identity()
              ..scale(_isHovered ? 1.03 : 1.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Section - Larger and more prominent
                    Expanded(
                      flex: 4,
                      child: Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFFFFF8F0),
                              Colors.white,
                              const Color(0xFFFFF5E6),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              widget.imageUrl != null
                                  ? Image.network(
                                      widget.imageUrl!,
                                      fit: BoxFit.contain,
                                      loadingBuilder:
                                          (context, child, loadingProgress) {
                                        if (loadingProgress == null)
                                          return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            color: const Color(0xFFFF7733),
                                            value: loadingProgress
                                                        .expectedTotalBytes !=
                                                    null
                                                ? loadingProgress
                                                          .cumulativeBytesLoaded /
                                                      loadingProgress
                                                          .expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.grey[100]!,
                                                Colors.grey[50]!,
                                              ],
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.shopping_bag_outlined,
                                            size: 100,
                                            color: Colors.grey[400],
                                          ),
                                        );
                                      },
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.grey[100]!,
                                            Colors.grey[50]!,
                                          ],
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.shopping_bag_outlined,
                                        size: 100,
                                        color: Colors.grey[400],
                                      ),
                                    ),
                              // Rating badge on top left
                              if (widget.rating > 0)
                                Positioned(
                                  top: 12,
                                  left: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.amber[600]!,
                                          Colors.amber[400]!,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withOpacity(0.4),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          widget.rating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Out of Stock badge
                              if (widget.isOutOfStock)
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          Colors.red[600]!,
                                          Colors.red[400]!,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.4),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'Out of Stock',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Content Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Category badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFF7733).withOpacity(0.15),
                                  const Color(0xFFFFA366).withOpacity(0.15),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFFF7733).withOpacity(0.4),
                                width: 1.5,
                              ),
                            ),
                            child: Text(
                              getCategoryNames(widget.product),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFFF7733),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Product ID
                          Text(
                            'ID: ${widget.product['product_id'] ?? widget.product['id'] ?? 'N/A'}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Product Name - Larger and bolder
                          Text(
                            widget.product['name'] ?? 'Product',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: _isHovered ? 17 : 16,
                              height: 1.3,
                              color: Colors.grey[900],
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Price - Large and prominent
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${widget.price} ₺',
                                    style: TextStyle(
                                      fontSize: _isHovered ? 24 : 22,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFF7733),
                                      height: 1,
                                    ),
                                  ),
                                  if (widget.stock > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            size: 12,
                                            color: Colors.green[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${widget.stock} available',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.green[700],
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              // Add to Cart button
                              if (!widget.isOutOfStock && widget.canAddToCart)
                                Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: widget.onAddToCart,
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(0xFFFF7733),
                                            const Color(0xFFFFA366),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFFF7733)
                                                .withOpacity(0.4),
                                            blurRadius: 8,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.add_shopping_cart,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'Add to Cart',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

extension _HomeScreenStateMethods on _HomeScreenState {
  Widget _buildPaginationControls(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: Offset(0, 4),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Previous Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _currentPage > 1
                        ? Color(0xFFFF7733).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentPage > 1
                          ? Color(0xFFFF7733).withOpacity(0.3)
                          : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chevron_left_rounded,
                        color: _currentPage > 1
                            ? Color(0xFFFF7733)
                            : Colors.grey[400],
                        size: 24,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Previous',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _currentPage > 1
                              ? Color(0xFFFF7733)
                              : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            
            // Page Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFF7733),
                    Color(0xFFFFA366),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFFFF7733).withOpacity(0.3),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$_currentPage',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF7733),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'of',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$totalPages',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            
            // Next Button
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _currentPage < totalPages
                        ? Color(0xFFFF7733).withOpacity(0.1)
                        : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _currentPage < totalPages
                          ? Color(0xFFFF7733).withOpacity(0.3)
                          : Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Next',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _currentPage < totalPages
                              ? Color(0xFFFF7733)
                              : Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _currentPage < totalPages
                            ? Color(0xFFFF7733)
                            : Colors.grey[400],
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleBanner() {
    if (_products.isEmpty) return const SizedBox.shrink();
    final featuredProduct = _products[0];
    final imageUrl = getProductImageUrl(featuredProduct);
    final price = featuredProduct['price'] ?? 0;
    final rating = featuredProduct['average_rating'] ?? 0.0;
    
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          _handleSearch("");
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetail(product: featuredProduct),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFF7733),
                const Color(0xFFFFA366),
                const Color(0xFFFF5500),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF7733).withOpacity(0.4),
                blurRadius: 30,
                offset: const Offset(0, 15),
                spreadRadius: 5,
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(40),
                child: Row(
                  children: [
                    // Left side - Product info
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sale badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Text(
                              'FLASH SALE',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF7733),
                                letterSpacing: 2,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Product name
                          Text(
                            featuredProduct['name'] ?? 'Featured Product',
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Description
                          if (featuredProduct['description'] != null)
                            Text(
                              featuredProduct['description'] ?? '',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.5,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 24),
                          // Rating and price row
                          Row(
                            children: [
                              // Rating
                              if (rating > 0) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Colors.amber,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        rating.toStringAsFixed(1),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              // Price
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '$price ₺',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFFF7733),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          // CTA Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  _handleSearch("");
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          ProductDetail(product: featuredProduct),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 16,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'Shop Now',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFFF7733),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      Icon(
                                        Icons.arrow_forward,
                                        color: Color(0xFFFF7733),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    // Right side - Product image
                    Expanded(
                      flex: 1,
                      child: Container(
                        height: 400,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: const Color(0xFFFF7733),
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[100],
                                      child: Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 80,
                                          color: Colors.grey[400],
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[100],
                                  child: Center(
                                    child: Icon(
                                      Icons.shopping_bag,
                                      size: 100,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                        ),
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
