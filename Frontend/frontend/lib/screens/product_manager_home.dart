import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import '../services/api_service.dart';
import '../services/product_manager_service.dart';
import 'login_screen.dart';
import 'product_manager_page.dart';

class ProductManagerHome extends StatefulWidget {
  final String username;
  final String role;

  const ProductManagerHome({super.key, required this.username, required this.role});

  @override
  State<ProductManagerHome> createState() => _ProductManagerHomeState();
}

class _ProductManagerHomeState extends State<ProductManagerHome> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final ProductManagerService _pmService = ProductManagerService();
  
  int _currentIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF5E6),
      appBar: AppBar(
        title: const Text('Product Manager Dashboard'),
        backgroundColor: const Color(0xFFFF7733),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.inventory), text: 'Products'),
            Tab(icon: Icon(Icons.local_shipping), text: 'Deliveries'),
            Tab(icon: Icon(Icons.rate_review), text: 'Reviews'),
            Tab(icon: Icon(Icons.receipt_long), text: 'Invoices'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ProductManagementTab(pmService: _pmService),
          _DeliveryManagementTab(pmService: _pmService),
          _ReviewModerationTab(apiService: _apiService),
          _InvoiceViewTab(pmService: _pmService),
        ],
      ),
    );
  }
}

// =====================================================
// Tab 1: Product & Stock Management
// =====================================================
class _ProductManagementTab extends StatefulWidget {
  final ProductManagerService pmService;
  const _ProductManagementTab({required this.pmService});

  @override
  State<_ProductManagementTab> createState() => _ProductManagementTabState();
}

class _ProductManagementTabState extends State<_ProductManagementTab> {
  List<dynamic> _products = [];
  List<String> _categories = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'All';

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
      final products = await widget.pmService.getProducts();
      final categories = await widget.pmService.getCategories();
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
      final matchesSearch = name.contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || p['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
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
    String? selectedImageUrl;
    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add New Product'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name *'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price *'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(labelText: 'Stock Quantity *'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.where((c) => c != 'All').map((c) =>
                    DropdownMenuItem(value: c, child: Text(c))
                  ).toList(),
                  onChanged: (v) => selectedCategory = v ?? selectedCategory,
                ),
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                TextField(
                  controller: serialController,
                  decoration: const InputDecoration(labelText: 'Serial Number'),
                ),
                TextField(
                  controller: warrantyController,
                  decoration: const InputDecoration(labelText: 'Warranty Status'),
                ),
                TextField(
                  controller: distributorController,
                  decoration: const InputDecoration(labelText: 'Distributor Info'),
                ),
                const SizedBox(height: 16),
                // Image picker section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      if (selectedImage != null) ...[
                        const Text('Image selected:', style: TextStyle(fontSize: 12, color: Colors.green)),
                        Text(selectedImage!.name, style: const TextStyle(fontSize: 10)),
                        const SizedBox(height: 8),
                      ],
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1920,
                            maxHeight: 1080,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setDialogState(() {
                              selectedImage = image;
                            });
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: Text(selectedImage == null ? 'Choose Image' : 'Change Image'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7733)),
            onPressed: () async {
              if (nameController.text.isEmpty || priceController.text.isEmpty || stockController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill required fields')),
                );
                return;
              }

              try {
                // Upload image first if selected
                String imageUrl = '';
                if (selectedImage != null) {
                  try {
                    print('📤 Uploading image: ${selectedImage!.name}');
                    final bytes = await selectedImage!.readAsBytes();
                    final base64Image = base64Encode(bytes);
                    print('📊 Image size: ${bytes.length} bytes, Base64 length: ${base64Image.length}');

                    final result = await widget.pmService.uploadProductImage(
                      fileName: selectedImage!.name,
                      base64Data: base64Image,
                      mimeType: selectedImage!.mimeType ?? 'image/jpeg',
                    );
                    imageUrl = result['url'] ?? '';
                    print('✅ Image uploaded: $imageUrl');
                  } catch (e) {
                    print('❌ Image upload error: $e');
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Image upload failed: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                    // Don't return here, continue with product creation without image
                  }
                }

                // Create product with image URL
                print('📦 Creating product with data...');
                final productData = {
                  'name': nameController.text,
                  'description': descController.text,
                  'price': double.parse(priceController.text),
                  'quantity_in_stock': int.parse(stockController.text),
                  'category': selectedCategory,
                  'model': modelController.text,
                  'serial_number': serialController.text,
                  'warranty_status': warrantyController.text,
                  'distributor_info': distributorController.text,
                  'image_url': imageUrl,
                };
                print('Product data: $productData');

                await widget.pmService.addProduct(productData);
                print('✅ Product added successfully');

                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Product added successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                print('❌ Product creation error: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    final nameController = TextEditingController(text: product['name']);
    final descController = TextEditingController(text: product['description'] ?? '');
    final priceController = TextEditingController(text: product['price']?.toString() ?? '');
    final modelController = TextEditingController(text: product['model'] ?? '');
    final serialController = TextEditingController(text: product['serial_number'] ?? '');
    final warrantyController = TextEditingController(text: product['warranty_status'] ?? '');
    final distributorController = TextEditingController(text: product['distributor_info'] ?? '');
    String selectedCategory = product['category'] ?? 'Uncategorized';
    String currentImageUrl = product['image_url'] ?? '';
    XFile? selectedImage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Edit: ${product['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Product Name *'),
                ),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 2,
                ),
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: 'Price *'),
                  keyboardType: TextInputType.number,
                ),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.where((c) => c != 'All').map((c) =>
                    DropdownMenuItem(value: c, child: Text(c))
                  ).toList(),
                  onChanged: (v) {
                    selectedCategory = v ?? selectedCategory;
                    setDialogState(() {});
                  },
                ),
                TextField(
                  controller: modelController,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                TextField(
                  controller: serialController,
                  decoration: const InputDecoration(labelText: 'Serial Number'),
                ),
                TextField(
                  controller: warrantyController,
                  decoration: const InputDecoration(labelText: 'Warranty Status'),
                ),
                TextField(
                  controller: distributorController,
                  decoration: const InputDecoration(labelText: 'Distributor Info'),
                ),
                const SizedBox(height: 16),
                // Image section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      if (currentImageUrl.isNotEmpty && selectedImage == null) ...[
                        const Text('Current Image:', style: TextStyle(fontSize: 12)),
                        const SizedBox(height: 8),
                        Image.network(
                          currentImageUrl,
                          height: 100,
                          errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, size: 50),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (selectedImage != null) ...[
                        const Text('New image selected:', style: TextStyle(fontSize: 12, color: Colors.green)),
                        Text(selectedImage!.name, style: const TextStyle(fontSize: 10)),
                        const SizedBox(height: 8),
                      ],
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1920,
                            maxHeight: 1080,
                            imageQuality: 85,
                          );
                          if (image != null) {
                            setDialogState(() {
                              selectedImage = image;
                            });
                          }
                        },
                        icon: const Icon(Icons.image),
                        label: Text(selectedImage == null && currentImageUrl.isEmpty
                          ? 'Add Image'
                          : 'Change Image'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7733)),
              onPressed: () async {
                if (nameController.text.isEmpty || priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields')),
                  );
                  return;
                }

                try {
                  // Upload new image if selected
                  String imageUrl = currentImageUrl;
                  if (selectedImage != null) {
                    try {
                      print('📤 Uploading new image: ${selectedImage!.name}');
                      final bytes = await selectedImage!.readAsBytes();
                      final base64Image = base64Encode(bytes);
                      print('📊 Image size: ${bytes.length} bytes');

                      final result = await widget.pmService.uploadProductImage(
                        fileName: selectedImage!.name,
                        base64Data: base64Image,
                        mimeType: selectedImage!.mimeType ?? 'image/jpeg',
                      );
                      imageUrl = result['url'] ?? currentImageUrl;
                      print('✅ Image uploaded: $imageUrl');
                    } catch (e) {
                      print('❌ Image upload error: $e');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Image upload failed: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                      // Continue with update using old image URL
                    }
                  }

                  // Update product
                  print('📝 Updating product: ${product['id']}');
                  await widget.pmService.updateProduct(product['id'], {
                    'name': nameController.text,
                    'description': descController.text,
                    'price': double.parse(priceController.text),
                    'category': selectedCategory,
                    'model': modelController.text,
                    'serial_number': serialController.text,
                    'warranty_status': warrantyController.text,
                    'distributor_info': distributorController.text,
                    'image_url': imageUrl,
                  });
                  print('✅ Product updated successfully');

                  Navigator.pop(ctx);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  print('❌ Product update error: $e');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
              },
              child: const Text('Update', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStockDialog(Map<String, dynamic> product) {
    final stockController = TextEditingController(
      text: (product['quantity_in_stock'] ?? 0).toString()
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Update Stock: ${product['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Current Stock: ${product['quantity_in_stock'] ?? 0}'),
            const SizedBox(height: 16),
            TextField(
              controller: stockController,
              decoration: const InputDecoration(labelText: 'New Stock Quantity'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7733)),
            onPressed: () async {
              try {
                await widget.pmService.updateStock(
                  product['id'],
                  absoluteValue: int.parse(stockController.text),
                );
                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stock updated successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Update', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Are you sure you want to delete "${product['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              try {
                await widget.pmService.deleteProduct(product['id']);
                Navigator.pop(ctx);
                _loadData();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCategoryManagementDialog() async {
    // Fetch all categories for management (including defaults and empty ones)
    List<String> allCategories;
    try {
      allCategories = await widget.pmService.getAllCategoriesForManagement();
    } catch (e) {
      allCategories = _categories.where((c) => c != 'All').toList();
    }
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (ctx) => _CategoryManagementDialog(
        pmService: widget.pmService,
        categories: allCategories,
        onUpdate: _loadData,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Search and Filter Bar
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v ?? 'All'),
                ),
              ),
            ],
          ),
        ),
        
        // Action Buttons
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7733)),
                onPressed: _showAddProductDialog,
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Add Product', style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _showCategoryManagementDialog,
                icon: const Icon(Icons.category),
                label: const Text('Manage Categories'),
              ),
              const Spacer(),
              Text('${_filteredProducts.length} products', style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ),

        // Products List
        Expanded(
          child: _filteredProducts.isEmpty
              ? const Center(child: Text('No products found'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = _filteredProducts[index];
                    final stock = product['quantity_in_stock'] ?? 0;
                    final isLowStock = stock < 10;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLowStock ? Colors.red.shade100 : const Color(0xFFFF7733).withOpacity(0.2),
                          child: Icon(
                            Icons.inventory_2,
                            color: isLowStock ? Colors.red : const Color(0xFFFF7733),
                          ),
                        ),
                        title: Text(product['name'] ?? 'Unknown'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Category: ${product['category'] ?? 'N/A'} | Price: \$${product['price'] ?? 0}'),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isLowStock ? Colors.red : Colors.green,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Stock: $stock',
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                                if (isLowStock) ...[
                                  const SizedBox(width: 8),
                                  const Text('⚠️ Low Stock', style: TextStyle(color: Colors.red, fontSize: 12)),
                                ],
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit Product')),
                            const PopupMenuItem(value: 'stock', child: Text('Update Stock')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.red))),
                          ],
                          onSelected: (value) {
                            if (value == 'edit') _showEditProductDialog(product);
                            if (value == 'stock') _showEditStockDialog(product);
                            if (value == 'delete') _showDeleteConfirmDialog(product);
                          },
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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

  @override
  void initState() {
    super.initState();
    _categories = List.from(widget.categories);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manage Categories'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newCategoryController,
                    decoration: const InputDecoration(hintText: 'New category name'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add, color: Color(0xFFFF7733)),
                  onPressed: () async {
                    if (_newCategoryController.text.isNotEmpty) {
                      try {
                        await widget.pmService.addCategory(_newCategoryController.text);
                        setState(() {
                          _categories.add(_newCategoryController.text);
                        });
                        _newCategoryController.clear();
                        widget.onUpdate();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _categories.length,
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(_categories[i]),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      try {
                        await widget.pmService.deleteCategory(_categories[i]);
                        setState(() {
                          _categories.removeAt(i);
                        });
                        widget.onUpdate();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e')),
                        );
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
          child: const Text('Close'),
        ),
      ],
    );
  }
}

// =====================================================
// Tab 2: Delivery Management
// =====================================================
class _DeliveryManagementTab extends StatefulWidget {
  final ProductManagerService pmService;
  const _DeliveryManagementTab({required this.pmService});

  @override
  State<_DeliveryManagementTab> createState() => _DeliveryManagementTabState();
}

class _DeliveryManagementTabState extends State<_DeliveryManagementTab> {
  List<dynamic> _deliveries = [];
  bool _loading = true;
  String? _error;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadDeliveries();
  }

  Future<void> _loadDeliveries() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final deliveries = await widget.pmService.getDeliveries();
      if (!mounted) return;
      setState(() {
        _deliveries = deliveries;
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

  List<dynamic> get _filteredDeliveries {
    if (_statusFilter == 'all') return _deliveries;
    return _deliveries.where((d) => d['status'] == _statusFilter).toList();
  }

  Future<void> _updateStatus(String orderId, String newStatus) async {
    try {
      await widget.pmService.updateOrderStatus(orderId, newStatus);
      _loadDeliveries();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to $newStatus')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            ElevatedButton(onPressed: _loadDeliveries, child: const Text('Retry')),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Filter Chips
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', _deliveries.length),
                const SizedBox(width: 8),
                _buildFilterChip('Processing', 'processing', 
                  _deliveries.where((d) => d['status'] == 'processing').length),
                const SizedBox(width: 8),
                _buildFilterChip('In Transit', 'in-transit',
                  _deliveries.where((d) => d['status'] == 'in-transit').length),
                const SizedBox(width: 8),
                _buildFilterChip('Delivered', 'delivered',
                  _deliveries.where((d) => d['status'] == 'delivered').length),
              ],
            ),
          ),
        ),

        // Deliveries List
        Expanded(
          child: _filteredDeliveries.isEmpty
              ? const Center(child: Text('No deliveries found'))
              : RefreshIndicator(
                  onRefresh: _loadDeliveries,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredDeliveries.length,
                    itemBuilder: (context, index) {
                      final delivery = _filteredDeliveries[index];
                      return _buildDeliveryCard(delivery);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, String value, int count) {
    final isSelected = _statusFilter == value;
    return FilterChip(
      label: Text('$label ($count)'),
      selected: isSelected,
      selectedColor: const Color(0xFFFF7733).withOpacity(0.2),
      checkmarkColor: const Color(0xFFFF7733),
      onSelected: (selected) {
        setState(() {
          _statusFilter = value;
        });
      },
    );
  }

  Widget _buildDeliveryCard(Map<String, dynamic> delivery) {
    final status = delivery['status'] ?? 'unknown';
    final items = delivery['items'] as List? ?? [];
    
    Color statusColor;
    switch (status) {
      case 'processing': statusColor = Colors.orange; break;
      case 'in-transit': statusColor = Colors.blue; break;
      case 'delivered': statusColor = Colors.green; break;
      default: statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.local_shipping, color: statusColor),
        ),
        title: Text('Delivery #${delivery['delivery_id'] ?? delivery['order_id']}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Customer: ${delivery['customer_id']}'),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status.toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Delivery Address
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Address: ${delivery['delivery_address'] ?? 'N/A'}')),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Total Price
                Row(
                  children: [
                    const Icon(Icons.attach_money, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text('Total: \$${delivery['total_price'] ?? 0}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Items
                const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Text('• Product ID: ${item['product_id']} | Qty: ${item['quantity']}'),
                )),
                
                const SizedBox(height: 16),
                
                // Action Buttons
                if (status != 'delivered')
                  Row(
                    children: [
                      if (status == 'processing')
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                            onPressed: () => _updateStatus(
                              delivery['order_id']?.toString() ?? delivery['delivery_id'],
                              'in-transit'
                            ),
                            icon: const Icon(Icons.local_shipping, color: Colors.white),
                            label: const Text('Ship', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                      if (status == 'in-transit')
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                            onPressed: () => _updateStatus(
                              delivery['order_id']?.toString() ?? delivery['delivery_id'],
                              'delivered'
                            ),
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text('Mark Delivered', style: TextStyle(color: Colors.white)),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================
// Tab 3: Review Moderation
// =====================================================
class _ReviewModerationTab extends StatefulWidget {
  final ApiService apiService;
  const _ReviewModerationTab({required this.apiService});

  @override
  State<_ReviewModerationTab> createState() => _ReviewModerationTabState();
}

class _ReviewModerationTabState extends State<_ReviewModerationTab> {
  List<dynamic> _pendingReviews = [];
  bool _loading = true;
  String? _error;
  final Set<String> _busyReviews = {};

  @override
  void initState() {
    super.initState();
    _fetchPendingReviews();
  }

  Future<void> _fetchPendingReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final reviews = await widget.apiService.getPendingReviewsForModeration();
    if (!mounted) return;
    setState(() {
      _pendingReviews = reviews;
      _loading = false;
    });
  }

  Future<void> _handleDecision(String reviewId, String decision) async {
    setState(() {
      _busyReviews.add(reviewId);
    });

    final success = await widget.apiService.updateReviewApproval(reviewId, decision);

    if (!mounted) return;
    setState(() {
      _busyReviews.remove(reviewId);
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Review ${decision == 'approved' ? 'approved' : 'rejected'}')),
      );
      await _fetchPendingReviews();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update review')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)));
    }

    return RefreshIndicator(
      onRefresh: _fetchPendingReviews,
      child: _pendingReviews.isEmpty
          ? const Center(child: Text('No reviews awaiting approval'))
            : ListView.builder(
              padding: const EdgeInsets.all(16),
                itemCount: _pendingReviews.length,
                itemBuilder: (context, index) {
                final review = _pendingReviews[index];
                final reviewId = review['review_id']?.toString() ?? review['id']?.toString() ?? '';
    final rating = (review['rating'] as num?)?.toDouble() ?? 0.0;
    final comment = review['comment']?.toString() ?? '';
    final author = review['author_name'] ?? 'Customer';
    final productId = review['product_id'];

    return Card(
                  margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                            Text('Product ID: $productId', style: const TextStyle(fontWeight: FontWeight.bold)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                              child: Text('⭐ ${rating.toStringAsFixed(1)}'),
                ),
              ],
            ),
                        const SizedBox(height: 8),
                        Text('By: $author'),
                        const SizedBox(height: 8),
                        Text(comment.isEmpty ? '(No comment)' : comment),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                                onPressed: _busyReviews.contains(reviewId)
                                    ? null
                                    : () => _handleDecision(reviewId, 'approved'),
                                icon: const Icon(Icons.check, color: Colors.white),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                label: const Text('Approve', style: TextStyle(color: Colors.white)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                                onPressed: _busyReviews.contains(reviewId)
                                    ? null
                                    : () => _handleDecision(reviewId, 'rejected'),
                    icon: const Icon(Icons.close, color: Colors.red),
                                style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                                label: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
            ),
          ],
        ),
                  ),
                );
              },
            ),
    );
  }
}

// =====================================================
// Tab 4: Invoice Viewing
// =====================================================
class _InvoiceViewTab extends StatefulWidget {
  final ProductManagerService pmService;
  const _InvoiceViewTab({required this.pmService});

  @override
  State<_InvoiceViewTab> createState() => _InvoiceViewTabState();
}

class _InvoiceViewTabState extends State<_InvoiceViewTab> {
  List<dynamic> _invoices = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final invoices = await widget.pmService.getInvoices();
      if (!mounted) return;
      setState(() {
        _invoices = invoices;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7733)));
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $_error'),
            ElevatedButton(onPressed: _loadInvoices, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInvoices,
      child: _invoices.isEmpty
          ? const Center(child: Text('No invoices found'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _invoices.length,
              itemBuilder: (context, index) {
                final invoice = _invoices[index];
                final items = invoice['items'] as List? ?? [];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ExpansionTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFF7733),
                      child: Icon(Icons.receipt, color: Colors.white),
                    ),
                    title: Text('Invoice #${invoice['order_id']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Customer: ${invoice['user_id']}'),
                        Text('Total: \$${invoice['total_amount'] ?? 0}',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${invoice['status']}'),
                            Text('Address: ${invoice['delivery_address'] ?? 'N/A'}'),
                            const SizedBox(height: 8),
                            const Text('Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                            ...items.map((item) => Padding(
                              padding: const EdgeInsets.only(left: 16, top: 4),
                              child: Text('• ${item['product_id']} x${item['quantity']} - \$${item['unit_price'] ?? 0}'),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
      ),
    );
  }
}
