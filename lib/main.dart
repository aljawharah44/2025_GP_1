
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // ضروري إذا كنت تستخدم Firebase
  runApp(const MunirApp());
}

class MunirApp extends StatelessWidget {
  const MunirApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Munir App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'YourFontName', 
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SplashScreen(),
    );
  }
}

