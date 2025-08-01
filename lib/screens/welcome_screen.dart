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
                      isPrimary: true,
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen()));
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildButton(
                      title: 'LOGIN',
                      color: const Color(0xFFE4BEEA),
                      textColor: Colors.white,
                      isPrimary: false,
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
    required bool isPrimary,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPrimary ? [
            color,
            color.withOpacity(0.8),
          ] : [
            color,
            color.withOpacity(0.9),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(isPrimary ? 0.4 : 0.25),
            blurRadius: isPrimary ? 16 : 12,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 1,
            offset: const Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withOpacity(0.2),
          highlightColor: Colors.white.withOpacity(0.1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}