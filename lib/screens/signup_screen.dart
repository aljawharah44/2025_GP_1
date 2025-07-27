import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/color.dart';
import 'get_started.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  bool _isLoading = false;

  void _registerUser() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
      // تسجيل المستخدم
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      // حفظ البيانات في Firestore
      User? user = userCredential.user;

      final String fullName = nameController.text.trim();

await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
  'full_name': fullName,
  'email': emailController.text.trim(),
  'phone': phoneController.text.trim(),
  'created_at': Timestamp.now(),
});
print("✅ تم حفظ بيانات المستخدم في Firestore");

// ✅ Success! انتقل للشاشة التالية
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => GetStartedScreen(fullName: fullName),
  ),
);


      } on FirebaseAuthException catch (e) {
        String error = "حدث خطأ";
        if (e.code == 'email-already-in-use') {
          error = "email-already-in-use";
        } else if (e.code == 'invalid-email') {
          error = "invalid-email";
        } else if (e.code == 'weak-password') {
          error = "weak-password";
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      } finally {
        setState(() => _isLoading = false);
      }
    }
    
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      fit: StackFit.expand,
      children: [
        // 🔲 الخلفية صورة
        Image.asset(
          'assets/images/signup_background.png',
          fit: BoxFit.cover,
        ),

        // 🔲 المحتوى الأمامي (فورم التسجيل)
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  /*const Text(
                    "New Account",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color.fromARGB(255, 43, 34, 34), // غيّر حسب وضوح الخلفية
                    ),
                    textAlign: TextAlign.center,
                  ),*/
                  const SizedBox(height: 50),

                  // باقي الفورم كما هو بدون تغيير:
                  _buildTextFormField(
                    controller: nameController,
                    hint: "Full name",
                    icon: Icons.person,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return "الاسم مطلوب";
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),
                  _buildTextFormField(
                    controller: emailController,
                    hint: "Email",
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return "البريد الإلكتروني مطلوب";
                      final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                      if (!emailRegex.hasMatch(value.trim())) return "تنسيق البريد غير صحيح";
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),
                  _buildTextFormField(
                    controller: phoneController,
                    hint: "Mobile Number",
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return "Mobile number is required.";
                      if (!RegExp(r'^[0-9]{9,15}$').hasMatch(value.trim())) return "Please enter a valid mobile number.";
                      return null;
                    },
                  ),

                  const SizedBox(height: 15),
                  _buildTextFormField(
                    controller: passwordController,
                    hint: "Password",
                    icon: Icons.lock,
                    obscure: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) return "Password is required.";
                      if (value.trim().length < 6) return "Password must be at least 6 characters long.";
                      return null;
                    },
                  ),

                  const SizedBox(height: 30),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          onPressed: _registerUser,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 197, 168, 221),
                            padding: const EdgeInsets.symmetric(horizontal: 130,vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(90)),
                          ),
                          child: const Text("Sign Up"),
                        ),

                  const SizedBox(height: 15),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Already have an account?", style: TextStyle(color: Color.fromARGB(255, 0, 0, 0))),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Log In"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildTextFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        fillColor: Colors.white,
        filled: true,
      ),
    );
  }
}
