import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PriceManagementPage extends StatefulWidget {
  const PriceManagementPage({Key? key}) : super(key: key);

  @override
  State<PriceManagementPage> createState() => _PriceManagementPageState();
}

class _PriceManagementPageState extends State<PriceManagementPage> {
  final ApiService _apiService = ApiService();
  List<dynamic> _products = [];
  List<dynamic> _filteredProducts = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  List<String> _categories = ['All'];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await _apiService.getProducts();

      // Extract unique categories from category or category_id
      final categories = <String>{'All'};
      for (var p in products) {
        final cat = p['category'] ?? _getCategoryName(p['category_id']);
        if (cat != null && cat.toString().isNotEmpty && cat != 'Uncategorized') {
          categories.add(cat.toString());
        }
      }

      setState(() {
        _products = products;
        _filteredProducts = products;
        _categories = categories.toList()..sort();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to load products: $e', isError: true);
    }
  }

  void _filterProducts() {
    setState(() {
      _filteredProducts = _products.where((p) {
        final name = (p['name'] ?? '').toString().toLowerCase();
        final matchesSearch = name.contains(_searchQuery.toLowerCase());
        final productCategory = p['category'] ?? _getCategoryName(p['category_id']);
        final matchesCategory = _selectedCategory == 'All' ||
            productCategory == _selectedCategory;
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }

  String _getCategoryName(dynamic categoryId) {
    if (categoryId == null) return 'Uncategorized';
    final Map<int, String> categoryMap = {
      1: 'Electronics',
      2: 'Clothing',
      3: 'Home & Garden',
      4: 'Computers',
      5: 'Audio',
      6: 'Mobile',
      7: 'Kitchen',
      8: 'Gaming',
      9: 'Sports',
      10: 'Books',
    };
    final id = int.tryParse(categoryId.toString()) ?? 0;
    return categoryMap[id] ?? 'Uncategorized';
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _showPriceDialog(Map<String, dynamic> product) async {
    final priceController = TextEditingController(
      text: (product['price'] ?? 0).toString(),
    );
    
    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Set Price'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product['name'] ?? 'Product',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            if (product['original_price'] != null)
              Text(
                'Original Price: \$${product['original_price']}',
                style: TextStyle(color: Colors.grey),
              ),
            SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'New Price (\$)',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(priceController.text);
              if (price != null && price >= 0) {
                Navigator.pop(context, price);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a valid price')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFFF7733),
            ),
            child: Text('Update Price'),
          ),
        ],
      ),
    );

    if (result != null) {
      try {
        final productId = product['id'] ?? product['product_id'];
        await _apiService.setProductPrice(productId.toString(), result);
        _showSnackBar('Price updated to \$${result.toStringAsFixed(2)}');
        _loadProducts();
      } catch (e) {
        _showSnackBar('Failed to update price: $e', isError: true);
      }
    }
  }

  Future<void> _showDiscountDialog(Map<String, dynamic> product) async {
    final discountController = TextEditingController(
      text: (product['discount_rate'] ?? 0).toString(),
    );
    
    final currentPrice = product['price'] ?? 0;
    final originalPrice = product['original_price'] ?? currentPrice;
    
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        double previewDiscount = (product['discount_rate'] ?? 0).toDouble();
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final previewPrice = previewDiscount > 0
                ? originalPrice * (1 - previewDiscount / 100)
                : originalPrice;
            
            return AlertDialog(
              title: Text('Set Discount'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'] ?? 'Product',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text('Original Price: \$${originalPrice.toStringAsFixed(2)}'),
                  SizedBox(height: 16),
                  TextField(
                    controller: discountController,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Discount Rate (%)',
                      prefixIcon: Icon(Icons.percent),
                      border: OutlineInputBorder(),
                      helperText: 'Enter 0-100',
                    ),
                    onChanged: (value) {
                      final discount = double.tryParse(value) ?? 0;
                      if (discount >= 0 && discount <= 100) {
                        setDialogState(() => previewDiscount = discount);
                      }
                    },
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFFF5E6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('New Price:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '\$${previewPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFF7733),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '⚠️ Users with this product in their wishlist will be notified via email.',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                if ((product['discount_rate'] ?? 0) > 0)
                  TextButton(
                    onPressed: () => Navigator.pop(context, 0.0),
                    child: Text('Remove Discount', style: TextStyle(color: Colors.red)),
                  ),
                ElevatedButton(
                  onPressed: () {
                    final discount = double.tryParse(discountController.text);
                    if (discount != null && discount >= 0 && discount <= 100) {
                      Navigator.pop(context, discount);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter a valid discount (0-100)')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF7733),
                  ),
                  child: Text('Apply Discount'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      try {
        final productId = product['id'] ?? product['product_id'];
        if (result == 0) {
          await _apiService.removeProductDiscount(productId.toString());
          _showSnackBar('Discount removed successfully');
        } else {
          final response = await _apiService.setProductDiscount(
            productId.toString(), 
            result,
          );
          final notifiedCount = response?['notified_users_count'] ?? 0;
          _showSnackBar(
            'Discount applied: ${result.toStringAsFixed(0)}% off. $notifiedCount user(s) notified.',
          );
        }
        _loadProducts();
      } catch (e) {
        _showSnackBar('Failed to update discount: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        title: Text(
          'Price & Discount Management',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Color(0xFFFF7733),
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(color: Colors.white),
        elevation: 2,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadProducts,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                  ),
                  onChanged: (value) {
                    _searchQuery = value;
                    _filterProducts();
                  },
                ),
                SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((category) {
                      final isSelected = _selectedCategory == category;
                      return Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(category),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() => _selectedCategory = category);
                            _filterProducts();
                          },
                          selectedColor: Color(0xFFFF7733),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Products List
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)))
                : _filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('No products found', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadProducts,
                        child: ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _filteredProducts.length,
                          itemBuilder: (context, index) {
                            final product = _filteredProducts[index];
                            return _buildProductCard(product);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final name = product['name'] ?? 'Unknown Product';
    final price = (product['price'] ?? 0).toDouble();
    final originalPrice = (product['original_price'] ?? price).toDouble();
    final discountRate = (product['discount_rate'] ?? 0).toDouble();
    final stock = product['quantity_in_stock'] ?? 0;
    final category = product['category'] ?? _getCategoryName(product['category_id']);
    final imageUrl = product['image_url'];

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 80,
                height: 80,
                color: Colors.grey[200],
                child: imageUrl != null && imageUrl.toString().isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_not_supported,
                          color: Colors.grey,
                        ),
                      )
                    : Icon(Icons.inventory_2, color: Colors.grey, size: 40),
              ),
            ),
            SizedBox(width: 12),
            
            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Category: $category',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  Text(
                    'Stock: $stock',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  SizedBox(height: 8),
                  
                  // Price Display
                  Row(
                    children: [
                      if (discountRate > 0) ...[
                        Text(
                          '\$${originalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        SizedBox(width: 8),
                      ],
                      Text(
                        '\$${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: discountRate > 0 ? Color(0xFFFF7733) : Colors.black,
                        ),
                      ),
                      if (discountRate > 0) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${discountRate.toStringAsFixed(0)}% OFF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Action Buttons
            Column(
              children: [
                IconButton(
                  icon: Icon(Icons.attach_money, color: Color(0xFFFF7733)),
                  onPressed: () => _showPriceDialog(Map<String, dynamic>.from(product)),
                  tooltip: 'Set Price',
                ),
                IconButton(
                  icon: Icon(
                    Icons.discount,
                    color: discountRate > 0 ? Colors.red : Colors.grey,
                  ),
                  onPressed: () => _showDiscountDialog(Map<String, dynamic>.from(product)),
                  tooltip: 'Set Discount',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

