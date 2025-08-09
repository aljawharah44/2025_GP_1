import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import './profile.dart';
import './face_management.dart';
import './camera.dart';
import './settings.dart';
import './reminders.dart';
import './sos_screen.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  bool _isProfileIncomplete = false;
  bool _isLoading = true;
  bool _isDismissed = false;

  @override
  void initState() {
    super.initState();
    _checkProfileCompleteness();
  }

  Future<void> _checkProfileCompleteness() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          final data = doc.data();

          // Check if essential profile fields are missing
          final bool isIncomplete =
              (data?['full_name']?.toString().trim().isEmpty ?? true) ||
              (data?['phone']?.toString().trim().isEmpty ?? true) ||
              (data?['address']?.toString().trim().isEmpty ?? true) ||
              (data?['country']?.toString().trim().isEmpty ?? true) ||
              (data?['city']?.toString().trim().isEmpty ?? true);

          setState(() {
            _isProfileIncomplete = isIncomplete;
            _isLoading = false;
          });
        } else {
          // No profile document exists - definitely incomplete
          setState(() {
            _isProfileIncomplete = true;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking profile: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF6B1D73);

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              Stack(
                children: [
                  Container(
                    height: 170,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                      ),
                      image: const DecorationImage(
                        image: AssetImage(
                          'assets/images/glass.png',
                        ), // Replace with your image path
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        // Purple overlay to maintain readability and theme
                        color: purple.withOpacity(0.7),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 40,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProfilePage(),
                          ),
                        ).then((_) {
                          // Refresh profile check when returning from profile page
                          _checkProfileCompleteness();
                        });
                      },
                      child: const CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, color: Colors.grey),
                      ),
                    ),
                  ),
                  const Positioned(
                    bottom: 30,
                    left: 20,
                    child: Text(
                      'Key Features',
                      style: TextStyle(
                        fontFamily: 'PlayfairDisplay',
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildFeatureCard('Face Recognition'),
                    _buildFeatureCard('Text Reading', highlight: true),
                    _buildFeatureCard('Alerts / Reminders'),
                    _buildFeatureCard('Currency Recognition', highlight: true),
                    _buildFeatureCard('Color Identification'),
                  ],
                ),
              ),
            ],
          ),

          // Centered notification for profile completion with grey background overlay
          if (!_isLoading && _isProfileIncomplete && !_isDismissed)
            Container(
              color: Colors.black.withOpacity(0.5), // Grey overlay background
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: 1.0,
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6B1D73), Color(0xFF9C4A9E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.account_circle_outlined,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Complete Your Profile',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please add your personal and address details to unlock all features!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isDismissed = true;
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Later',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ProfilePage(),
                                  ),
                                ).then((_) {
                                  // Refresh profile check when returning from profile page
                                  _checkProfileCompleteness();
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFF6B1D73),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 2,
                              ),
                              child: const Text(
                                'Complete Now',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Color(0xFFB14ABA),
        unselectedItemColor: Colors.black,
        backgroundColor: Colors.grey.shade200,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RemindersPage()),
            );
          } else if (index == 2) {
            final user = _auth.currentUser;
            final userName = user?.displayName ?? user?.email ?? 'User';

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SosScreen(userName: userName),
              ),
            );
          } else if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsPage()),
            );
          }
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
            icon: Icon(Icons.warning_amber_outlined),
            label: 'Emergency',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  static Widget _buildFeatureCard(String title, {bool highlight = false}) {
    String imageName = '';
    String description = '';

    switch (title) {
      case 'Face Recognition':
        imageName = 'facerecog.jpg';
        description = 'Identify and recognize people';
        break;
      case 'Text Reading':
        imageName = 'textreading.jpg';
        description = 'Read printed text aloud';
        break;
      case 'Alerts / Reminders':
        imageName = 'reminders.jpg';
        description = 'Read printed text aloud';
        break;
      case 'Currency Recognition':
        imageName = 'currency.jpg';
        description = 'Identify different currencies';
        break;
      case 'Color Identification':
        imageName = 'color.jpg';
        description = 'Detect and identify colors';
        break;
      default:
        description = 'Feature description';
        break;
    }

    return Builder(
      builder: (context) => Card(
        color: highlight ? const Color(0xAA6B1D73) : const Color(0xAAC8B8E4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: ListTile(
          leading: Container(
            width: 50,
            height: 50,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: imageName.isNotEmpty
                ? Image.asset('assets/images/$imageName', fit: BoxFit.contain)
                : const Icon(Icons.image, color: Colors.white),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            description,
            style: const TextStyle(fontSize: 13), // Change font size here
          ), // Now shows unique description for each feature
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            if (title == 'Face Recognition') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FaceManagementPage(),
                ),
              );
            } else if (title == 'Alerts / Reminders') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RemindersPage()),
              );
            } else if (title == 'Text Reading' ||
                title == 'Currency Recognition' ||
                title == 'Color Identification') {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CameraScreen()),
              );
            }
          },
        ),
      ),
    );
  }
}
