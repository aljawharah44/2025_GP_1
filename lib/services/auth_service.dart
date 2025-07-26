import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// تسجيل الدخول بالبريد وكلمة المرور
  static Future<User?> signInWithEmail({
  required String email,
  required String password,
  required BuildContext context,
}) async {
  try {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return userCredential.user;
  } on FirebaseAuthException catch (e) {
    String message = "Login failed";

    if (e.code == 'user-not-found') {
      // ✅ Check if this email is registered with Google
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
      if (methods.contains('google.com')) {
        message = "This account was created using Google. Please sign in using the Google button.";
      } else {
        message = "No account found for this email.";
      }
    } else if (e.code == 'wrong-password') {
  final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email);
  if (methods.contains('google.com')) {
    message = "This account was created using Google. Please sign in using the Google button.";
  } else {
    message = "Incorrect password.";
  }
}


    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return null;
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("An unexpected error occurred.")),
    );
    return null;
  }
}


  /// التحقق من وجود المستخدم عن طريق الإيميل
  static Future<bool> checkIfUserExists(String email) async {
    try {
      final methods = await _auth.fetchSignInMethodsForEmail(email);
      return methods.isNotEmpty;
    } catch (e) {
      print("Error checking user existence: $e");
      return false;
    }
  }

  /// تسجيل الدخول السريع وإرجاع الحالة
  static Future<bool> signIn(String email, String password, BuildContext context) async {
    final user = await signInWithEmail(email: email, password: password, context: context);
    return user != null;
  }

  /// تسجيل دخول فيسبوك (غير مفعّل حاليًا)
  static Future<void> signInWithFacebook(BuildContext context) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Facebook Sign-in not implemented')),
    );
  }

  /// جلب اسم المستخدم من Firestore
  static Future<String> getFullName(String uid) async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return (doc.get('full_name') ?? 'User');
      } else {
        return 'User';
      }
    } catch (e) {
      print('Error getting full name: $e');
      return 'User';
    }
  }
}
