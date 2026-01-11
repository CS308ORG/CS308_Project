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

  // Design constants
  static const Color _primaryText = Color(0xFF1A1A2E);
  static const Color _secondaryText = Color(0xFF6B7280);
  static const Color _accentColor = Color(0xFF1E3A8A);
  static const Color _borderColor = Color(0xFFE5E7EB);
  static const Color _cardBackground = Colors.white;
  static const Color _pageBackground = Color(0xFFFFF5E6); // Match site theme

  Map<String, dynamic>? _userInfo;
  bool _loading = true;
  bool _isEditing = false;
  bool _showTaxID = false;
  bool _showPassword = false;

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
            _passwordController.text = userInfo['password'] ?? '';
            _loading = false;
          });
        } else {
          setState(() => _loading = false);
        }
      } catch (e) {
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
    if (_nameController.text != (_userInfo?['name'] ?? '')) updates['name'] = _nameController.text;
    if (_emailController.text != (_userInfo?['email'] ?? '')) updates['email'] = _emailController.text;
    if (_addressController.text != (_userInfo?['address'] ?? '')) updates['address'] = _addressController.text;
    if (_taxIDController.text != (_userInfo?['taxID'] ?? '')) updates['taxID'] = _taxIDController.text;
    if (_passwordController.text.isNotEmpty) updates['password'] = _passwordController.text;

    if (updates.isEmpty) {
      setState(() => _isEditing = false);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: _accentColor)),
    );

    try {
      final success = await _apiService.updateUserInfo(uid, updates);
      if (mounted) {
        Navigator.pop(context);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Information updated successfully'), backgroundColor: Colors.green),
          );
          setState(() {
            _isEditing = false;
            _passwordController.clear();
          });
          _fetchUserInfo();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update information'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StoreLayout(
      body: Container(
        color: _pageBackground,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 80),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "MY INFORMATION",
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: 4,
                                    color: _primaryText,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(width: 40, height: 2, color: _accentColor),
                              ],
                            ),
                            _buildActionButton(),
                          ],
                        ),
                      ),

                      // Content
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(48.0),
                          child: Center(child: CircularProgressIndicator(color: _accentColor, strokeWidth: 2)),
                        )
                      else if (_userInfo == null)
                        Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.person_off_outlined, size: 64, color: _secondaryText.withValues(alpha: 0.3)),
                                const SizedBox(height: 16),
                                Text('Failed to load user information', style: TextStyle(color: _secondaryText)),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: _cardBackground,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 20, offset: const Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customer ID (always read-only)
                              _buildReadOnlyField(
                                'Customer ID',
                                _userInfo!['user_id']?.toString() ?? _userInfo!['id']?.toString() ?? 'N/A',
                                Icons.badge_outlined,
                              ),
                              const SizedBox(height: 24),

                              if (!_isEditing) ...[
                                _buildInfoField('Full Name', _userInfo!['name'] ?? '', Icons.person_outline),
                                _buildInfoField('Email Address', _userInfo!['email'] ?? '', Icons.email_outlined),
                                _buildInfoField('Home Address', _userInfo!['address'] ?? '', Icons.home_outlined),
                                _buildInfoField('Tax ID', _userInfo!['taxID'] ?? '', Icons.receipt_long_outlined, isSensitive: true, showField: _showTaxID, onToggle: () => setState(() => _showTaxID = !_showTaxID)),
                                _buildInfoField('Password', _userInfo!['password'] ?? '', Icons.lock_outline, isSensitive: true, showField: _showPassword, onToggle: () => setState(() => _showPassword = !_showPassword)),
                              ] else ...[
                                _buildEditableField('Full Name', _nameController, Icons.person_outline, validator: (v) => v == null || v.isEmpty ? 'Name is required' : null),
                                _buildEditableField('Email Address', _emailController, Icons.email_outlined, validator: (v) {
                                  if (v == null || v.isEmpty) return 'Email is required';
                                  if (!v.contains('@')) return 'Invalid email format';
                                  return null;
                                }),
                                _buildEditableField('Home Address', _addressController, Icons.home_outlined),
                                _buildEditableField('Tax ID', _taxIDController, Icons.receipt_long_outlined, isSensitive: true, showField: _showTaxID, onToggle: () => setState(() => _showTaxID = !_showTaxID)),
                                _buildEditableField('New Password', _passwordController, Icons.lock_outline, isSensitive: true, showField: _showPassword, onToggle: () => setState(() => _showPassword = !_showPassword), validator: (v) {
                                  if (v != null && v.isNotEmpty && v.length < 6) return 'Password must be at least 6 characters';
                                  return null;
                                }, hint: 'Leave empty to keep current'),
                              ],

                              // Save/Cancel Buttons
                              if (_isEditing) ...[
                                const SizedBox(height: 32),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () {
                                          setState(() {
                                            _isEditing = false;
                                            _nameController.text = _userInfo?['name'] ?? '';
                                            _emailController.text = _userInfo?['email'] ?? '';
                                            _addressController.text = _userInfo?['address'] ?? '';
                                            _taxIDController.text = _userInfo?['taxID'] ?? '';
                                            _passwordController.clear();
                                          });
                                        },
                                        style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: _borderColor),
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: Text('Cancel', style: TextStyle(color: _secondaryText)),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: _saveChanges,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _accentColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(vertical: 16),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                          elevation: 0,
                                        ),
                                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w500)),
                                      ),
                                    ),
                                  ],
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
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    if (_isEditing) return const SizedBox.shrink();

    return OutlinedButton.icon(
      onPressed: () => setState(() => _isEditing = true),
      icon: const Icon(Icons.edit_outlined, size: 18),
      label: const Text('Edit'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _accentColor,
        side: BorderSide(color: _accentColor),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: _accentColor, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11, color: _secondaryText, letterSpacing: 1, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(value, style: TextStyle(fontSize: 15, color: _primaryText, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoField(String label, String value, IconData icon, {bool isSensitive = false, bool showField = false, VoidCallback? onToggle}) {
    final displayValue = value.isEmpty ? 'Not set' : (isSensitive && !showField ? '••••••••' : value);

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: _secondaryText, letterSpacing: 1, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _borderColor),
            ),
            child: Row(
              children: [
                Icon(icon, color: _secondaryText, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    displayValue,
                    style: TextStyle(fontSize: 15, color: value.isEmpty ? _secondaryText.withValues(alpha: 0.5) : _primaryText),
                  ),
                ),
                if (isSensitive)
                  GestureDetector(
                    onTap: onToggle,
                    child: Icon(showField ? Icons.visibility : Icons.visibility_off, color: _secondaryText, size: 20),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, IconData icon, {bool isSensitive = false, bool showField = false, VoidCallback? onToggle, String? Function(String?)? validator, String? hint}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: _secondaryText, letterSpacing: 1, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: isSensitive && !showField,
            validator: validator,
            style: TextStyle(fontSize: 15, color: _primaryText),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: _secondaryText.withValues(alpha: 0.5), fontSize: 14),
              prefixIcon: Icon(icon, color: _secondaryText, size: 20),
              suffixIcon: isSensitive
                  ? GestureDetector(
                      onTap: onToggle,
                      child: Icon(showField ? Icons.visibility : Icons.visibility_off, color: _secondaryText, size: 20),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _borderColor)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: _accentColor, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.red.shade300)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.red.shade300, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }
}
