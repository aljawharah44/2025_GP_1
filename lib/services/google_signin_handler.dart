import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import '../screens/get_started.dart';

class GoogleSignInHandler {
  // Configure GoogleSignIn with explicit client ID - REQUIRED for idToken
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
  scopes: [
    'email',
    'profile',
  ],
);

  static Future<void> signInWithGoogle(BuildContext context) async {
    try {
      // Check if Google Play Services is available
      final bool isAvailable = await _googleSignIn.isSignedIn();
      print("📱 Google Sign-In available: $isAvailable");

      // Sign out first to ensure clean sign-in
      await _googleSignIn.signOut();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        print("❌ User cancelled Google Sign-In");
        return; // User cancelled the sign-in
      }

      print("✅ Google user signed in: ${googleUser.email}");

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      print("🔑 Access Token: ${googleAuth.accessToken != null ? 'Available' : 'NULL'}");
      print("🔑 ID Token: ${googleAuth.idToken != null ? 'Available' : 'NULL'}");

      AuthCredential credential;

      // Alternative approach if tokens are null
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        print("⚠️ Tokens are null, trying alternative approach...");
        
        // Sign out and try again with explicit scopes
        await _googleSignIn.signOut();
        
        // Try with specific scopes
        final GoogleSignInAccount? retryUser = await _googleSignIn.signIn();
        if (retryUser == null) return;
        
        final GoogleSignInAuthentication retryAuth = await retryUser.authentication;
        print("🔄 Retry - Access Token: ${retryAuth.accessToken != null ? 'Available' : 'NULL'}");
        print("🔄 Retry - ID Token: ${retryAuth.idToken != null ? 'Available' : 'NULL'}");
        
        if (retryAuth.accessToken == null || retryAuth.idToken == null) {
          throw Exception('Failed to get authentication tokens after retry. Please check your Web Client ID configuration.');
        }
        
        // Use retry tokens
        credential = GoogleAuthProvider.credential(
          accessToken: retryAuth.accessToken,
          idToken: retryAuth.idToken,
        );
      } else {
        // Use original tokens
        credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
      }

      print("✅ Created Firebase credential");

      // Sign in to Firebase with the Google credential
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        print("✅ Firebase user signed in: ${user.uid}");

        // Check if user document exists in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        String fullName = user.displayName ?? "User";

        if (!userDoc.exists) {
          // First time user, create their document
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'full_name': fullName,
            'email': user.email,
            'photo_url': user.photoURL,
            'provider': 'google',
            'created_at': Timestamp.now(),
            'last_login': Timestamp.now(),
          });
          print("✅ Created new user document");
        } else {
          // Existing user, update last login and get stored name
          fullName = userDoc.data()?['full_name'] ?? fullName;
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
            'last_login': Timestamp.now(),
          });
          print("✅ Updated existing user document");
        }

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text("Welcome, $fullName!"),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }

        // Navigate to GetStarted screen with smooth animation
        if (context.mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => 
                  GetStartedScreen(fullName: fullName),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print("❌ Firebase Auth Error: ${e.code} - ${e.message}");
      String errorMessage = "Authentication failed";
      
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = "An account already exists with a different sign-in method";
          break;
        case 'invalid-credential':
          errorMessage = "Invalid credentials provided";
          break;
        case 'operation-not-allowed':
          errorMessage = "Google sign-in is not enabled";
          break;
        case 'user-disabled':
          errorMessage = "This account has been disabled";
          break;
        default:
          errorMessage = e.message ?? "Authentication failed";
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      print("❌ Error signing in with Google: $e");
      
      String errorMessage = "Google sign-in failed";
      if (e.toString().contains('ApiException: 10')) {
        errorMessage = "Configuration error. Please check app setup.";
      } else if (e.toString().contains('network_error')) {
        errorMessage = "Network error. Please check your connection.";
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // Helper method to sign out
  static Future<void> signOut() async {
    try {
      await Future.wait([
        FirebaseAuth.instance.signOut(),
        _googleSignIn.signOut(),
      ]);
      print("✅ User signed out successfully");
    } catch (e) {
      print("❌ Error signing out: $e");
    }
  }

  // Helper method to check if user is signed in
  static Future<bool> isSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      print("❌ Error checking sign-in status: $e");
      return false;
    }
  }
}