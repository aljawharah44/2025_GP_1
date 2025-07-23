import 'package:flutter/material.dart';
import '../constants/color.dart';
import 'signup_screen.dart';
import 'set_password_screen.dart';
import '../auth_service.dart'; // 👈 هنا الاستيراد
import "handle_google_signin.dart";

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

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
              hint: "Email or Mobile Number",
              icon: Icons.person,
            ),
            const SizedBox(height: 15),
            _buildTextField(
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
              onPressed: () {
                // TODO: login action
              },
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
                  onTap: () => handleGoogleSignIn(context),
                  child: Icon(Icons.g_mobiledata, size: 36),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.facebook, size: 30),
                  onPressed: () {
                    // TODO: Facebook login
                  },
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.fingerprint, size: 30),
                  onPressed: () {
                    // TODO: Fingerprint login
                  },
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
          ],  // <-- هنا تغلق قائمة الـ children بقوس مربع فقط
        ),
      ),
    );
  }

  static Widget _buildTextField({
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
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
