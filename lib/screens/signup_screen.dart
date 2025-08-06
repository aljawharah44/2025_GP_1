import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'get_started.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/google_signin_handler.dart'; // Add this import

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  String _getPasswordStrength(String password) {
    if (password.length < 6) return 'Weak';
    if (password.length < 8) return 'Medium';
    if (RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]').hasMatch(password)) {
      return 'Strong';
    }
    return 'Medium';
  }

  Color _getPasswordStrengthColor(String password) {
    final strength = _getPasswordStrength(password);
    switch (strength) {
      case 'Weak': return Colors.red;
      case 'Medium': return Colors.orange;
      case 'Strong': return Colors.green;
      default: return Colors.grey;
    }
  }

  void _registerUser() async {
    if (!_agreeToTerms) {
      _showSnackBar("Please agree to the Terms & Conditions", Colors.red);
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        // Register user
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );

        // Save data to Firestore
        User? user = userCredential.user;
        final String fullName = nameController.text.trim();

        await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
          'full_name': fullName,
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
          'created_at': Timestamp.now(),
          'profile_completed': false,
        });

        // Send email verification
        await user.sendEmailVerification();

        _showSnackBar("Account created successfully! Please verify your email.", Colors.green);

        // Navigate to next screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GetStartedScreen(fullName: fullName),
          ),
        );

      } on FirebaseAuthException catch (e) {
        String error = "An error occurred";
        switch (e.code) {
          case 'email-already-in-use':
            error = "This email is already registered";
            break;
          case 'invalid-email':
            error = "Please enter a valid email address";
            break;
          case 'weak-password':
            error = "Password is too weak";
            break;
          case 'operation-not-allowed':
            error = "Email/password accounts are not enabled";
            break;
          default:
            error = e.message ?? "Registration failed";
        }
        _showSnackBar(error, Colors.red);
      } catch (e) {
        _showSnackBar("An unexpected error occurred", Colors.red);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Add Google sign-in method
  Future<void> _signUpWithGoogle() async {
    if (!_agreeToTerms) {
      _showSnackBar("Please agree to the Terms & Conditions", Colors.red);
      return;
    }

    try {
      setState(() => _isLoading = true);
      await GoogleSignInHandler.signInWithGoogle(context);
    } catch (e) {
      _showSnackBar("Google sign-up failed", Colors.red);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == Colors.green ? Icons.check_circle : 
              color == Colors.orange ? Icons.warning : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Enhanced background with gradient overlay
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/backk.jpg'),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        
                        // Header section
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person_add_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                "Create Account",
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                "Join us and start your journey",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 30),

                        // Form fields
                        _buildEnhancedTextFormField(
                          controller: nameController,
                          hint: "Full Name",
                          icon: Icons.person_outline,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Full name is required";
                            }
                            if (value.trim().length < 2) {
                              return "Name must be at least 2 characters";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        
                        _buildEnhancedTextFormField(
                          controller: emailController,
                          hint: "Email Address",
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Email is required";
                            }
                            final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                            if (!emailRegex.hasMatch(value.trim())) {
                              return "Please enter a valid email address";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        
                        _buildEnhancedTextFormField(
                          controller: phoneController,
                          hint: "Mobile Number",
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Mobile number is required";
                            }
                            if (!RegExp(r'^[0-9+\-\s()]{8,15}$').hasMatch(value.trim())) {
                              return "Please enter a valid mobile number";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 16),
                        
                        _buildPasswordField(
                          controller: passwordController,
                          hint: "Password",
                          obscure: _obscurePassword,
                          onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Password is required";
                            }
                            if (value.trim().length < 6) {
                              return "Password must be at least 6 characters";
                            }
                            return null;
                          },
                        ),
                        
                        // Password strength indicator
                        if (passwordController.text.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.security,
                                  size: 16,
                                  color: _getPasswordStrengthColor(passwordController.text),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Password Strength: ${_getPasswordStrength(passwordController.text)}",
                                  style: TextStyle(
                                    color: _getPasswordStrengthColor(passwordController.text),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 16),
                        
                        _buildPasswordField(
                          controller: confirmPasswordController,
                          hint: "Confirm Password",
                          obscure: _obscureConfirmPassword,
                          onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return "Please confirm your password";
                            }
                            if (value != passwordController.text) {
                              return "Passwords do not match";
                            }
                            return null;
                          },
                        ),

                        const SizedBox(height: 20),

                        // Terms and conditions checkbox
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _agreeToTerms,
                                onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
                                activeColor: const Color(0xFF6B1D73),
                                checkColor: Colors.white,
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => _agreeToTerms = !_agreeToTerms),
                                  child: RichText(
                                    text: TextSpan(
                                      style: const TextStyle(color: Colors.white, fontSize: 14),
                                      children: [
                                        const TextSpan(text: "I agree to the "),
                                        TextSpan(
                                          text: "Terms & Conditions",
                                          style: TextStyle(
                                            color: const Color(0xFF6B1D73),
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                        const TextSpan(text: " and "),
                                        TextSpan(
                                          text: "Privacy Policy",
                                          style: TextStyle(
                                            color: const Color(0xFF6B1D73),
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
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

                        const SizedBox(height: 30),

                        // Sign up button
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _registerUser,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color.fromARGB(255, 162, 68, 172),
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: const Color(0xFF6B1D73).withOpacity(0.3),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 24,
                                    width: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Create Account",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        // Divider (similar to login screen)
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                "OR",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Google sign-up button
                        _buildSocialButton(
                          icon: Icons.g_mobiledata,
                          onTap: _signUpWithGoogle,
                          label: "Sign up with Google",
                        ),

                        const SizedBox(height: 30),

                        // Login link
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Already have an account? ",
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 16,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: const Text(
                                  "log In",
                                  style: TextStyle(
                                    color: Color(0xFF6B1D73),
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedTextFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        validator: validator,
        onChanged: (value) => setState(() {}), // For real-time validation
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B1D73).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: const Color(0xFF6B1D73),
              size: 20,
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          fillColor: Colors.white.withOpacity(0.95),
          filled: true,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        validator: validator,
        onChanged: (value) => setState(() {}),
        style: const TextStyle(color: Colors.black, fontSize: 16),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade600),
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF6B1D73).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.lock_outline,
              color: const Color(0xFF6B1D73),
              size: 20,
            ),
          ),
          suffixIcon: IconButton(
            onPressed: onToggle,
            icon: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF6B1D73),
            ),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          fillColor: Colors.white.withOpacity(0.95),
          filled: true,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }

  // Add social button widget (similar to login screen)
  Widget _buildSocialButton({
    required IconData icon,
    required VoidCallback onTap,
    required String label,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}