import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import '../screens/get_started.dart';

class GoogleSignInHandler {
  static Future<void> signInWithGoogle(BuildContext context) async {
  try {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // Cancelled

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        // أول مرة، خزّن بياناته
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'full_name': user.displayName ?? "User",
          'email': user.email,
          'created_at': Timestamp.now(),
        });
      }

      final fullName = userDoc.data()?['full_name'] ?? user.displayName ?? "User";

      // ✅ انتقل إلى صفحة get started
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => GetStartedScreen(fullName: fullName)),
      );
    }
  } catch (e) {
    print("❌ Error signing in with Google: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("فشل تسجيل الدخول عبر Google")),
    );
  }
}

}
