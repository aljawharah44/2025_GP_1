import 'package:flutter/material.dart';
import '../constants/color.dart';
import 'signup_screen.dart';
import 'set_password_screen.dart';
import 'get_started.dart';
import '../services/auth_service.dart';
import '../services/google_signin_handler.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LocalAuthentication _localAuth = LocalAuthentication();

  void _login() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();

  if (email.isEmpty || password.isEmpty) {
    _showMessage("Please fill in all fields");
    return;
  }

  final user = await AuthService.signInWithEmail(
    email: email,
    password: password,
    context: context,
  );

  if (user != null) {
    final fullName = await AuthService.getFullName(user.uid);
    _showMessage("Login successful");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GetStartedScreen(fullName: fullName)),
    );
  } else {
    // ما يحتاج تنقله لصفحة التسجيل هنا، بس تعرض له رسالة خطأ
    _showMessage("Invalid email or password");
  }
}


  Future<void> _loginWithFingerprint() async {
    bool canAuthenticate = await _localAuth.canCheckBiometrics;
    if (!canAuthenticate) {
      _showMessage("Biometric not available");
      return;
    }

    bool authenticated = await _localAuth.authenticate(
      localizedReason: 'Authenticate to login',
    );

    if (authenticated) {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    final fullName = await AuthService.getFullName(user.uid);
    _showMessage("Fingerprint recognized. Welcome!");
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GetStartedScreen(fullName: fullName)),
    );
  } else {
    _showMessage("User not found");
  }
}

  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: ListView(
          children: [
            const SizedBox(height: 80),
            const Text(
              "Login Account",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),
            const Text(
              "Welcome Back!",
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            _buildTextField(
              controller: _emailController,
              hint: "Email or Mobile Number",
              icon: Icons.person,
            ),
            const SizedBox(height: 15),
            _buildTextField(
              controller: _passwordController,
              hint: "Password",
              icon: Icons.lock,
              obscure: true,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SetPasswordScreen()));
                },
                child: const Text("Forget Password?"),
              ),
            ),
            ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 197, 168, 221),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text("Log In"),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                 onTap: () => GoogleSignInHandler.signInWithGoogle(context),
                  child: const Icon(Icons.g_mobiledata, size: 36),
                ), 
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.facebook, size: 30),
                  onPressed: () {
                    AuthService.signInWithFacebook(context);
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.fingerprint, size: 30),
                  onPressed: _loginWithFingerprint,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don’t have an account?"),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                  },
                  child: const Text("Sign Up"),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixIcon: obscure ? const Icon(Icons.visibility_off) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        fillColor: Colors.white,
        filled: true,
      ),
    );
  }
}
