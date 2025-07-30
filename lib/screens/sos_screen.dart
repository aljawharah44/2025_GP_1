import 'package:flutter/material.dart';

class SosScreen extends StatelessWidget {
  final String userName;

  const SosScreen({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ✅ BottomNavigationBar معدّل
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: const Color(0xFFB14ABA),
        unselectedItemColor: Colors.black,
        backgroundColor: Colors.white,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          // تأكد من إضافة التوجيه المناسب هنا حسب الصفحة
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_none),
            label: 'Reminders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_outlined, color: Color(0xFFB14ABA)), // ✅ لون مميز لأيقونة Emergency
            label: 'Emergency',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.topRight,
              child: Icon(Icons.notifications_none),
            ),
            const SizedBox(height: 10),
            Text(
              'Hey!',
              style: TextStyle(fontSize: 20, color: Colors.grey.shade700),
            ),
            Text(
              userName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
            const SizedBox(height: 30),

            // ✅ النصوص على اليسار وبخط أصغر
            const Text(
              'Help is just a click away!',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 4),
            const Text(
              'Click SOS button to call the help.',
              style: TextStyle(fontSize: 12, color: Colors.purple),
              textAlign: TextAlign.left,
            ),

            const Spacer(),
            const Center(child: SosButton()),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}

class SosButton extends StatefulWidget {
  const SosButton({super.key});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildPulse({required double scale, required double opacity}) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red.withOpacity(opacity),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              _buildPulse(scale: _pulseAnimation.value * 1.2, opacity: 0.1),
              _buildPulse(scale: _pulseAnimation.value * 1.0, opacity: 0.15),
              _buildPulse(scale: _pulseAnimation.value * 0.8, opacity: 0.2),

              // زر SOS الأساسي
              ElevatedButton(
                onPressed: () {
                  // SOS Logic
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(60),
                  elevation: 10,
                ),
                child: const Text(
                  'SOS',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}