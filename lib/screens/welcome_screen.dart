import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🔲 الخلفية (الصورة)
          Image.asset(
            'assets/images/start_background.png',
            fit: BoxFit.cover,
          ),

          // 🔲 المحتوى الأمامي: الأزرار والنص
          Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  children: [
                    _buildButton(
                      title: 'Signup',
                      color: const Color(0xFFB14ABA),
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      title: 'LOGIN',
                      color: const Color(0xFFE4BEEA),
                      textColor: Colors.white,
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  "By creating an account, you agree to our\nTerms and Conditions policy",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildButton({
    required String title,
    required VoidCallback onPressed,
    required Color color,
    required Color textColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(title, style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
