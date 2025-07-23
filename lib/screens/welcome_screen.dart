import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';
import '../constants/color.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          _buildTopCurve(),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ✅ عنوان التطبيق
                const Text(
                  "MUNIR",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: Color.fromARGB(255, 222, 99, 234),
                    letterSpacing: 2,
                  ),
                ),

                const SizedBox(height: 16),

                // ✅ وصف ترحيبي جديد
                Text(
                  "Get started with Munir",
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),

                const SizedBox(height: 40),

                // ✅ زر Signup
                _buildButton(
                  context,
                  title: "Signup",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                ),

                const SizedBox(height: 15),

                // ✅ زر Login
                _buildButton(
                  context,
                  title: "LOGIN",
                  isFilled: false,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),

                const SizedBox(height: 30),

                // ✅ نص تحت الأزرار
                Text(
                  "By creating an account, you agree to our\nTerms and Conditions policy",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.lightText),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // ✅ شكل الخلفية العلوية المنحنية
  Widget _buildTopCurve() {
    return ClipPath(
      clipper: TopCurveClipper(),
      child: Container(
        height: 240,
        color: const Color.fromARGB(255, 115, 7, 119),
        child: ClipPath(
          clipper: InnerCurveClipper(),
          child: Container(
            height: 240,
            color: const Color.fromARGB(255, 234, 204, 246),
          ),
        ),
      ),
    );
  }

  // ✅ بناء زر مخصص
  Widget _buildButton(BuildContext context,
      {required String title, required VoidCallback onPressed, bool isFilled = true}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isFilled
            ? const Color.fromARGB(255, 110, 3, 122)
            : AppColors.secondary,
        foregroundColor: isFilled ? Colors.white : Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 100, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(title),
    );
  }
}

// ✅ الشكل الخارجي للمنحنى العلوي
class TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
        size.width / 2, size.height + 40, size.width, size.height - 40);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ✅ الشكل الداخلي للمنحنى العلوي
class InnerCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 80);
    path.quadraticBezierTo(
        size.width / 2, size.height + 60, size.width, size.height - 60);
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
