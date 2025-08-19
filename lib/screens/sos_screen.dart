import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_page.dart';
import 'Reminders.dart';
import 'settings.dart';
import 'location_selection_page.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key}); // ✅ removed userName parameter

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final user = FirebaseAuth.instance.currentUser;

  void _onNavTap(BuildContext context, int index) {
    if (index == 0) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomePage()),
      );
    } else if (index == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const RemindersPage()),
      );
    } else if (index == 2) {
      // Already on SOS screen
    } else if (index == 3) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SettingsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 2,
        selectedItemColor: const Color(0xFFB14ABA),
        unselectedItemColor: Colors.black,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        onTap: (index) => _onNavTap(context, index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.notifications_none), label: 'Reminders'),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber_outlined, color: Color(0xFFB14ABA)),
            label: 'Emergency',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
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

            // ✅ Firestore StreamBuilder to fetch live user name
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }

                var userData = snapshot.data!.data() as Map<String, dynamic>?;

                String name = "User";
                if (userData != null && userData.containsKey('full_name')) {
                  name = userData['full_name'];
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hey!",
                      style: TextStyle(fontSize: 20, color: Colors.grey.shade700),
                    ),
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            const Text(
              'Help is just a click away!',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            const Text(
              'Click SOS button to call the help.',
              style: TextStyle(fontSize: 12, color: Colors.purple),
            ),

            const Spacer(),
            SosButton(onLocationSent: _showSuccessDialog),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        Timer(const Duration(seconds: 5), () {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Help is on the way.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class SosButton extends StatefulWidget {
  final Function(BuildContext) onLocationSent;

  const SosButton({super.key, required this.onLocationSent});

  @override
  State<SosButton> createState() => _SosButtonState();
}

class _SosButtonState extends State<SosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;
  bool _isProcessing = false;

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

  Future<void> _handleSosPress() async {
    if (_isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const LocationSelectionPage()),
      );

      if (result == true && mounted) {
        widget.onLocationSent(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send location. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
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
              if (!_isProcessing) ...[
                _buildPulse(scale: _pulseAnimation.value * 1.2, opacity: 0.1),
                _buildPulse(scale: _pulseAnimation.value * 1.0, opacity: 0.15),
                _buildPulse(scale: _pulseAnimation.value * 0.8, opacity: 0.2),
              ],
              ElevatedButton(
                onPressed: _isProcessing ? null : _handleSosPress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isProcessing ? Colors.grey : Colors.red,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(60),
                  elevation: 10,
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      )
                    : const Text(
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
