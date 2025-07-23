import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'get_started.dart';

Future<void> handleGoogleSignIn(BuildContext context) async {
  try {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) return; // المستخدم لغى العملية

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user != null) {
      // تحقق إذا المستخدم موجود في Firestore
      final DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final String fullName = userDoc['full_name'];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GetStartedScreen(fullName: fullName),
          ),
        );
      } else {
        // المستخدم مسجل دخول بقوقل لكن ما عنده بيانات في Firestore
        // إما تسجل له بيانات جديدة أو ترسله يسجل حسابه يدويًا
        // مثال: تسجل له تلقائيًا:
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'full_name': user.displayName ?? '',
          'email': user.email,
          'created_at': Timestamp.now(),
        });

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => GetStartedScreen(fullName: user.displayName ?? ''),
          ),
        );
      }
    }
  } catch (e) {
    print("❌ Error signing in with Google: $e");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Google Sign-in failed. Please try again.")),
    );
  }
}
