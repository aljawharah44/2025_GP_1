import 'package:flutter/material.dart';
import './profile.dart';
import './face_management.dart';
import './camera.dart'; // ✅ إضافة ملف الكاميرا

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(
            children: [
              Container(
                height: 220,
                decoration: const BoxDecoration(
                  color: Color(0xFF6B1D73),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
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
                    );
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
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF6B1D73),
        unselectedItemColor: Colors.grey,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Emergency',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Setting'),
        ],
      ),
    );
  }

  static Widget _buildFeatureCard(String title, {bool highlight = false}) {
    String imageName = '';
    switch (title) {
      case 'Face Recognition':
        imageName = 'facerecog.jpg';
        break;
      case 'Text Reading':
        imageName = 'textreading.jpg';
        break;
      case 'Alerts / Reminders':
        imageName = 'reminders.jpg';
        break;
      case 'Currency Recognition':
        imageName = 'currency.jpg';
        break;
      case 'Color Identification':
        imageName = 'color.jpg';
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
          subtitle: const Text('Body copy description'),
          trailing: const Icon(Icons.arrow_forward_ios),
          onTap: () {
            if (title == 'Face Recognition') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FaceManagementPage(),
                ),
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
