import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'signup_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    TextInput.finishAutofillContext();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    bool success = await AuthService().login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (success) {
      if (!mounted) return;
      Navigator.pop(context, true);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Email or password is incorrect, or you have not an account yet.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
        child: SingleChildScrollView(
          child: Padding(
                  padding: EdgeInsets.all(24),
            child: Container(
                    constraints: BoxConstraints(maxWidth: 450),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo/Title Section
                        Container(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFFF7733),
                                      Color(0xFFFFA366),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFFFF7733).withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.shopping_bag_rounded,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 24),
                              Text(
                                'Welcome Back',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFFF7733),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Sign in to continue shopping',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: 32),

                        // Form Card
                        Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 30,
                                offset: Offset(0, 15),
                                spreadRadius: 0,
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                                  // Email Field
                      TextFormField(
                        controller: _emailController,
                        autofillHints: const [
                          AutofillHints.email,
                          AutofillHints.username,
                        ],
                                    keyboardType: TextInputType.emailAddress,
                                    style: TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Email',
                                      labelStyle: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.email_outlined,
                                        color: Color(0xFFFF7733),
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey[200]!,
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Color(0xFFFF7733),
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return 'Please enter your email';
                                      }
                                      if (!val.contains('@')) {
                                        return 'Please enter a valid email';
                                      }
                                      return null;
                                    },
                                  ),
                                  SizedBox(height: 20),

                                  // Password Field
                      TextFormField(
                        controller: _passwordController,
                        autofillHints: const [AutofillHints.password],
                                    obscureText: _obscurePassword,
                                    style: TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: 'Password',
                                      labelStyle: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 16,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.lock_outlined,
                                        color: Color(0xFFFF7733),
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: Colors.grey[400],
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _obscurePassword = !_obscurePassword;
                                          });
                                        },
                                      ),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.grey[200]!,
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Color(0xFFFF7733),
                                          width: 2,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: Colors.red,
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    validator: (val) {
                                      if (val == null || val.isEmpty) {
                                        return 'Please enter your password';
                                      }
                                      return null;
                                    },
                      ),
                      SizedBox(height: 24),

                                  // Error Message
                      if (_errorMessage != null)
                        Container(
                                      padding: EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.red[200]!,
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.red[700],
                                            size: 20,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                          child: Text(
                            _errorMessage!,
                                              style: TextStyle(
                                                color: Colors.red[700],
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (_errorMessage != null) SizedBox(height: 20),

                                  // Login Button
                                  Container(
                                    height: 56,
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
                                          color: Color(0xFFFF7733).withOpacity(0.4),
                                          blurRadius: 15,
                                          offset: Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _isLoading ? null : _login,
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          alignment: Alignment.center,
                          child: _isLoading
                                              ? SizedBox(
                                                  width: 24,
                                                  height: 24,
                                                  child: CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              : Text(
                                                  'Sign In',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 24),

                                  // Sign Up Link
                                  Center(
                                    child: RichText(
                        text: TextSpan(
                                        text: "Don't have an account? ",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 15,
                                        ),
                          children: [
                            TextSpan(
                                            text: 'Sign Up',
                              style: TextStyle(
                                              color: Color(0xFFFF7733),
                                fontWeight: FontWeight.bold,
                                              fontSize: 15,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SignupScreen(),
                                    ),
                                  );
                                },
                            ),
                          ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
      ),
    );
  }
}
