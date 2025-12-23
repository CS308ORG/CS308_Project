import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';

class CustomerInformationPage extends StatefulWidget {
  @override
  _CustomerInformationPageState createState() => _CustomerInformationPageState();
}

class _CustomerInformationPageState extends State<CustomerInformationPage> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();
  
  Map<String, dynamic>? _userInfo;
  bool _loading = true;
  bool _isEditing = false;
  bool _showTaxID = false;
  bool _showPassword = false;
  
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _taxIDController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _taxIDController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchUserInfo() async {
    setState(() => _loading = true);
    String? uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null && AuthService().isLoggedIn) {
      final currentUser = AuthService().currentUser;
      uid = currentUser?['id']?.toString() ?? currentUser?['user_id']?.toString();
    }

    if (uid != null) {
      try {
        final userInfo = await _apiService.getUserInfo(uid);
        if (userInfo != null) {
          setState(() {
            _userInfo = userInfo;
            _nameController.text = userInfo['name'] ?? '';
            _emailController.text = userInfo['email'] ?? '';
            _addressController.text = userInfo['address'] ?? '';
            _taxIDController.text = userInfo['taxID'] ?? '';
            _passwordController.text = userInfo['password'] ?? ''; // Show password from database
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      } catch (e) {
        print("Error fetching user info: $e");
        setState(() => _loading = false);
      }
    } else {
      setState(() => _loading = false);
    }
  }
  
  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null && AuthService().isLoggedIn) {
      final currentUser = AuthService().currentUser;
      uid = currentUser?['id']?.toString() ?? currentUser?['user_id']?.toString();
    }
    
    if (uid == null) return;
    
    final updates = <String, dynamic>{};
    if (_nameController.text != (_userInfo?['name'] ?? '')) {
      updates['name'] = _nameController.text;
    }
    if (_emailController.text != (_userInfo?['email'] ?? '')) {
      updates['email'] = _emailController.text;
    }
    if (_addressController.text != (_userInfo?['address'] ?? '')) {
      updates['address'] = _addressController.text;
    }
    if (_taxIDController.text != (_userInfo?['taxID'] ?? '')) {
      updates['taxID'] = _taxIDController.text;
    }
    if (_passwordController.text.isNotEmpty) {
      updates['password'] = _passwordController.text;
    }
    
    if (updates.isEmpty) {
      setState(() => _isEditing = false);
      return;
    }
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    
    try {
      final success = await _apiService.updateUserInfo(uid, updates);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Information updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {
            _isEditing = false;
            _passwordController.clear(); // Clear password field
          });
          _fetchUserInfo(); // Refresh data
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update information'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Widget _buildInfoField(String label, String value, {bool isSensitive = false}) {
    // Determine if this field should show/hide based on toggle state
    bool isVisible = false;
    if (isSensitive) {
      if (label.contains('Tax ID')) {
        isVisible = _showTaxID;
      } else if (label.contains('Password')) {
        isVisible = _showPassword;
      }
    } else {
      isVisible = true; // Non-sensitive fields are always visible
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value.isEmpty ? 'Not set' : (isSensitive && !isVisible ? '••••••••' : value),
                    style: TextStyle(
                      fontSize: 16,
                      color: value.isEmpty ? Colors.grey.shade400 : Colors.black87,
                    ),
                  ),
                ),
                if (isSensitive)
                  IconButton(
                    icon: Icon(
                      isVisible ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey.shade600,
                    ),
                    onPressed: () {
                      setState(() {
                        if (label.contains('Tax ID')) {
                          _showTaxID = !_showTaxID;
                        } else if (label.contains('Password')) {
                          _showPassword = !_showPassword;
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEditableField(String label, TextEditingController controller, {bool isSensitive = false, String? Function(String?)? validator}) {
    // Determine if this field should show/hide based on toggle state
    bool isVisible = false;
    if (isSensitive) {
      if (label.contains('Tax ID')) {
        isVisible = _showTaxID;
      } else if (label.contains('Password')) {
        isVisible = _showPassword;
      }
    } else {
      isVisible = true; // Non-sensitive fields are always visible
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: isSensitive && !isVisible,
            validator: validator,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFFF7733), width: 2),
              ),
              suffixIcon: isSensitive
                  ? IconButton(
                      icon: Icon(
                        isVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey.shade600,
                      ),
                      onPressed: () {
                        setState(() {
                          if (label.contains('Tax ID')) {
                            _showTaxID = !_showTaxID;
                          } else if (label.contains('Password')) {
                            _showPassword = !_showPassword;
                          }
                        });
                      },
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return StoreLayout(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "My Information",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                        color: Color(0xFFFF7733),
                      ),
                    ),
                    if (!_isEditing)
                      ElevatedButton.icon(
                        onPressed: () => setState(() => _isEditing = true),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7733),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      )
                    else
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = false;
                                // Reset controllers
                                _nameController.text = _userInfo?['name'] ?? '';
                                _emailController.text = _userInfo?['email'] ?? '';
                                _addressController.text = _userInfo?['address'] ?? '';
                                _taxIDController.text = _userInfo?['taxID'] ?? '';
                                _passwordController.clear();
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveChanges,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF7733),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            child: const Text('Save'),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 32),
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_userInfo == null)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Failed to load user information'),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_isEditing) ...[
                          _buildInfoField('Customer ID', _userInfo!['user_id']?.toString() ?? _userInfo!['id']?.toString() ?? 'N/A'),
                          _buildInfoField('Name', _userInfo!['name'] ?? '', isSensitive: false),
                          _buildInfoField('Email', _userInfo!['email'] ?? '', isSensitive: false),
                          _buildInfoField('Home Address', _userInfo!['address'] ?? '', isSensitive: false),
                          _buildInfoField('Tax ID', _userInfo!['taxID'] ?? '', isSensitive: true),
                          _buildInfoField('Password', _userInfo!['password'] ?? '', isSensitive: true),
                        ] else ...[
                          _buildInfoField('Customer ID', _userInfo!['user_id']?.toString() ?? _userInfo!['id']?.toString() ?? 'N/A'),
                          _buildEditableField(
                            'Name',
                            _nameController,
                            validator: (value) => value == null || value.isEmpty ? 'Name is required' : null,
                          ),
                          _buildEditableField(
                            'Email',
                            _emailController,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Email is required';
                              if (!value.contains('@')) return 'Invalid email format';
                              return null;
                            },
                          ),
                          _buildEditableField(
                            'Home Address',
                            _addressController,
                          ),
                          _buildEditableField(
                            'Tax ID',
                            _taxIDController,
                            isSensitive: true,
                          ),
                          _buildEditableField(
                            'Password (leave empty to keep current)',
                            _passwordController,
                            isSensitive: true,
                            validator: (value) {
                              if (value != null && value.isNotEmpty && value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
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
      ),
    );
  }
}

