import 'package:flutter/material.dart';

class LocationPermissionScreen extends StatelessWidget {
  const LocationPermissionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
  children: [
    // صورة الخلفية مع شفافية
    Opacity(
      opacity: 0.3, // نسبة الشفافية من 0 (شفاف تماماً) إلى 1 (واضحة تماماً)
      child: Image.asset(
        'assets/images/map_background.jpg',
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    ),

    // باقي المحتوى فوق الصورة
    Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(20),
              child: const Icon(Icons.location_on, size: 50, color: Colors.purple),
            ),
            const SizedBox(height: 20),
            const Text(
              'Track yourself',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.purple),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please allow location permission.',
              style: TextStyle(fontSize: 14, color: Color.fromARGB(196, 0, 0, 0)),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () {
                      // تقدر تضيف logic هنا
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color.fromARGB(255, 197, 168, 221),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Allow'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                      // تخطي
                    },
              child: const Text('Skip for now'),
            ),
          ],
        ),
      ),
    ),
  ],
),

    );
  }
}
