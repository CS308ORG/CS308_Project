import 'package:flutter/material.dart';
import '../services/product_manager_service.dart';

class StockManagementPage extends StatefulWidget {
  const StockManagementPage({Key? key}) : super(key: key);

  @override
  State<StockManagementPage> createState() => _StockManagementPageState();
}

class _StockManagementPageState extends State<StockManagementPage> {
  final ProductManagerService _pmService = ProductManagerService();
  List<dynamic> _products = [];
  List<String> _categories = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _stockFilter = 'all'; // all, low, out

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final products = await _pmService.getProducts();
      final categories = await _pmService.getCategories();
      if (!mounted) return;
      setState(() {
        _products = products;
        _categories = ['All', ...categories];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<dynamic> get _filteredProducts {
    return _products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final stock = p['quantity_in_stock'] ?? 0;
      
      final matchesSearch = name.contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || p['category'] == _selectedCategory;
      
      bool matchesStockFilter = true;
      if (_stockFilter == 'low') {
        matchesStockFilter = stock > 0 && stock < 10;
      } else if (_stockFilter == 'out') {
        matchesStockFilter = stock == 0;
      }
      
      return matchesSearch && matchesCategory && matchesStockFilter;
    }).toList();
  }

  int get _totalProducts => _products.length;
  int get _lowStockCount => _products.where((p) => (p['quantity_in_stock'] ?? 0) > 0 && (p['quantity_in_stock'] ?? 0) < 10).length;
  int get _outOfStockCount => _products.where((p) => (p['quantity_in_stock'] ?? 0) == 0).length;

  void _showUpdateStockDialog(Map<String, dynamic> product) {
    final stockController = TextEditingController(
      text: (product['quantity_in_stock'] ?? 0).toString()
    );
    final adjustmentController = TextEditingController();
    bool useAbsolute = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.inventory_2, color: Color(0xFFFF7733)),
              SizedBox(width: 8),
              Expanded(child: Text('Update Stock', overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product['name'] ?? 'Unknown Product',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 20, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text('Current Stock: ${product['quantity_in_stock'] ?? 0}'),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                
                // Toggle between absolute and adjustment
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => useAbsolute = true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: useAbsolute ? Color(0xFFFF7733) : Colors.grey[200],
                            borderRadius: BorderRadius.horizontal(left: Radius.circular(8)),
                          ),
                          child: Text(
                            'Set Value',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: useAbsolute ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setDialogState(() => useAbsolute = false),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !useAbsolute ? Color(0xFFFF7733) : Colors.grey[200],
                            borderRadius: BorderRadius.horizontal(right: Radius.circular(8)),
                          ),
                          child: Text(
                            'Adjust (+/-)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: !useAbsolute ? Colors.white : Colors.grey[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                
                if (useAbsolute)
                  TextField(
                    controller: stockController,
                    decoration: InputDecoration(
                      labelText: 'New Stock Quantity',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory),
                    ),
                    keyboardType: TextInputType.number,
                  )
                else
                  TextField(
                    controller: adjustmentController,
                    decoration: InputDecoration(
                      labelText: 'Adjustment (e.g., +10 or -5)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.add_circle_outline),
                      helperText: 'Use positive to add, negative to subtract',
                    ),
                    keyboardType: TextInputType.numberWithOptions(signed: true),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF7733)),
              onPressed: () async {
                try {
                  if (useAbsolute) {
                    final newStock = int.tryParse(stockController.text);
                    if (newStock == null || newStock < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter a valid positive number')),
                      );
                      return;
                    }
                    await _pmService.updateStock(product['id'], absoluteValue: newStock);
                  } else {
                    final adjustment = int.tryParse(adjustmentController.text);
                    if (adjustment == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please enter a valid number')),
                      );
                      return;
                    }
                    await _pmService.updateStock(product['id'], adjustment: adjustment);
                  }
                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Stock updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              child: Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProductDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final priceController = TextEditingController();
    final stockController = TextEditingController();
    final modelController = TextEditingController();
    final serialController = TextEditingController();
    final warrantyController = TextEditingController();
    final distributorController = TextEditingController();
    String selectedCategory = _categories.length > 1 ? _categories[1] : 'Uncategorized';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.add_box, color: Color(0xFFFF7733)),
            SizedBox(width: 8),
            Text('Add New Product'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Product Name *', border: OutlineInputBorder()),
              ),
              SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      decoration: InputDecoration(labelText: 'Price *', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: stockController,
                      decoration: InputDecoration(labelText: 'Stock *', border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
                items: _categories.where((c) => c != 'All').map((c) => 
                  DropdownMenuItem(value: c, child: Text(c))
                ).toList(),
                onChanged: (v) => selectedCategory = v ?? selectedCategory,
              ),
              SizedBox(height: 12),
              TextField(
                controller: modelController,
                decoration: InputDecoration(labelText: 'Model', border: OutlineInputBorder()),
              ),
              SizedBox(height: 12),
              TextField(
                controller: serialController,
                decoration: InputDecoration(labelText: 'Serial Number', border: OutlineInputBorder()),
              ),
              SizedBox(height: 12),
              TextField(
                controller: warrantyController,
                decoration: InputDecoration(labelText: 'Warranty Status', border: OutlineInputBorder()),
              ),
              SizedBox(height: 12),
              TextField(
                controller: distributorController,
                decoration: InputDecoration(labelText: 'Distributor Info', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF7733)),
            onPressed: () async {
              if (nameController.text.isEmpty || priceController.text.isEmpty || stockController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fill required fields')),
                );
                return;
              }
              try {
                await _pmService.addProduct({
                  'name': nameController.text,
                  'description': descController.text,
                  'price': double.parse(priceController.text),
                  'quantity_in_stock': int.parse(stockController.text),
                  'category': selectedCategory,
                  'model': modelController.text,
                  'serial_number': serialController.text,
                  'warranty_status': warrantyController.text,
                  'distributor_info': distributorController.text,
                });
                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Product added successfully'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: Text('Add Product', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Delete Product'),
          ],
        ),
        content: Text('Are you sure you want to delete "${product['name']}"?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await _pmService.deleteProduct(product['id']);
                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Product deleted successfully'), backgroundColor: Colors.green),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                );
              }
            },
            child: Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCategoryManagementDialog() async {
    // Fetch all categories for management (including defaults and empty ones)
    List<String> allCategories;
    try {
      allCategories = await _pmService.getAllCategoriesForManagement();
    } catch (e) {
      allCategories = _categories.where((c) => c != 'All').toList();
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => _CategoryManagementDialog(
        pmService: _pmService,
        categories: allCategories,
        onUpdate: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFFF5E6),
      appBar: AppBar(
        title: Text('Stock & Product Management'),
        backgroundColor: Color(0xFFFF7733),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Error: $_error'),
                      SizedBox(height: 16),
                      ElevatedButton(onPressed: _loadData, child: Text('Retry')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Stats Cards
                    Container(
                      padding: EdgeInsets.all(16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          _buildStatCard('Total', _totalProducts, Colors.blue, Icons.inventory_2),
                          SizedBox(width: 12),
                          _buildStatCard('Low Stock', _lowStockCount, Colors.orange, Icons.warning),
                          SizedBox(width: 12),
                          _buildStatCard('Out of Stock', _outOfStockCount, Colors.red, Icons.block),
                        ],
                      ),
                    ),
                    
                    // Search and Filter
                    Container(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          TextField(
                            decoration: InputDecoration(
                              hintText: 'Search products...',
                              prefixIcon: Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (v) => setState(() => _searchQuery = v),
                          ),
                          SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: InputDecoration(
                                    labelText: 'Category',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                                  onChanged: (v) => setState(() => _selectedCategory = v ?? 'All'),
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _stockFilter,
                                  decoration: InputDecoration(
                                    labelText: 'Stock Status',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: [
                                    DropdownMenuItem(value: 'all', child: Text('All')),
                                    DropdownMenuItem(value: 'low', child: Text('Low Stock')),
                                    DropdownMenuItem(value: 'out', child: Text('Out of Stock')),
                                  ],
                                  onChanged: (v) => setState(() => _stockFilter = v ?? 'all'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Action Buttons
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFFFF7733)),
                            onPressed: _showAddProductDialog,
                            icon: Icon(Icons.add, color: Colors.white),
                            label: Text('Add Product', style: TextStyle(color: Colors.white)),
                          ),
                          SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _showCategoryManagementDialog,
                            icon: Icon(Icons.category),
                            label: Text('Categories'),
                          ),
                          Spacer(),
                          Text('${_filteredProducts.length} products', 
                            style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    SizedBox(height: 8),

                    // Products List
                    Expanded(
                      child: _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inventory_2, size: 64, color: Colors.grey[400]),
                                  SizedBox(height: 16),
                                  Text('No products found', style: TextStyle(color: Colors.grey[600])),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
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

  Widget _buildStatCard(String title, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
            ),
            Text(title, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final stock = product['quantity_in_stock'] ?? 0;
    final isOutOfStock = stock == 0;
    final isLowStock = stock > 0 && stock < 10;

    Color stockColor = Colors.green;
    String stockLabel = 'In Stock';
    if (isOutOfStock) {
      stockColor = Colors.red;
      stockLabel = 'Out of Stock';
    } else if (isLowStock) {
      stockColor = Colors.orange;
      stockLabel = 'Low Stock';
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: stockColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.inventory_2, color: stockColor),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['name'] ?? 'Unknown',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Category: ${product['category'] ?? 'N/A'} | Price: \$${product['price'] ?? 0}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton(
                  icon: Icon(Icons.more_vert),
                  itemBuilder: (ctx) => [
                    PopupMenuItem(
                      value: 'edit_stock',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Update Stock'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'edit_stock') {
                      _showUpdateStockDialog(product);
                    } else if (value == 'delete') {
                      _showDeleteConfirmDialog(product);
                    }
                  },
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: stockColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOutOfStock ? Icons.block : (isLowStock ? Icons.warning : Icons.check_circle),
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Stock: $stock',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8),
                Text(stockLabel, style: TextStyle(color: stockColor, fontWeight: FontWeight.w500)),
                Spacer(),
                TextButton.icon(
                  onPressed: () => _showUpdateStockDialog(product),
                  icon: Icon(Icons.edit, size: 16),
                  label: Text('Update'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Category Management Dialog
class _CategoryManagementDialog extends StatefulWidget {
  final ProductManagerService pmService;
  final List<String> categories;
  final VoidCallback onUpdate;

  const _CategoryManagementDialog({
    required this.pmService,
    required this.categories,
    required this.onUpdate,
  });

  @override
  State<_CategoryManagementDialog> createState() => _CategoryManagementDialogState();
}

class _CategoryManagementDialogState extends State<_CategoryManagementDialog> {
  late List<String> _categories;
  final _newCategoryController = TextEditingController();
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.category, color: Color(0xFFFF7733)),
          SizedBox(width: 8),
          Text('Manage Categories'),
        ],
      ),
      content: SizedBox(
        width: 350,
        height: 400,
        child: Column(
          children: [
            // Add new category
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    decoration: InputDecoration(
                      hintText: 'New category name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                _isAdding
                    ? CircularProgressIndicator(strokeWidth: 2)
                    : IconButton(
                        icon: Icon(Icons.add_circle, color: Color(0xFFFF7733), size: 32),
                        onPressed: () async {
                          if (_newCategoryController.text.trim().isEmpty) return;
                          
                          setState(() => _isAdding = true);
                          try {
                            await widget.pmService.addCategory(_newCategoryController.text.trim());
                            setState(() {
                              _categories.add(_newCategoryController.text.trim());
                              _newCategoryController.clear();
                            });
                            widget.onUpdate();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Category added'), backgroundColor: Colors.green),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          } finally {
                            setState(() => _isAdding = false);
                          }
                        },
                      ),
              ],
            ),
            SizedBox(height: 16),
            Divider(),
            SizedBox(height: 8),
            
            // Category list
            Expanded(
              child: _categories.isEmpty
                  ? Center(child: Text('No categories', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _categories.length,
                      itemBuilder: (ctx, i) => ListTile(
                        leading: Icon(Icons.folder, color: Color(0xFFFF7733)),
                        title: Text(_categories[i]),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('Delete Category'),
                                content: Text('Delete "${_categories[i]}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('Cancel'),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: Text('Delete', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            
                            if (confirm == true) {
                              try {
                                await widget.pmService.deleteCategory(_categories[i]);
                                setState(() => _categories.removeAt(i));
                                widget.onUpdate();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Category deleted'), backgroundColor: Colors.green),
                                );
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Close'),
        ),
      ],
    );
  }
}

