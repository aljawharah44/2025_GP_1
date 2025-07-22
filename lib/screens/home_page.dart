import 'package:flutter/material.dart';
import './profile.dart';

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
                left: 16,
                child: GestureDetector(
                  onTap: () {
                    // TODO: Navigate to drawer/menu page
                  },
                  child: const Icon(Icons.menu, color: Colors.white, size: 28),
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

          // ✅ المسافة تحت الهيدر
          const SizedBox(height: 16),

          // ✅ قائمة الميزات داخل Column
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
    return Card(
      color: highlight
          ? const Color(0xAA6B1D73) // غامق مع شفافية
          : const Color(0xAAC8B8E4), // فاتح مع شفافية
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 10), // مسافة بين العناصر
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          color: Colors.grey.shade300,
          child: const Icon(Icons.image, color: Colors.white),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Body copy description'),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () {},
      ),
    );
  }
}
