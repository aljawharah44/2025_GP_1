import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DeviceAlertsPage extends StatefulWidget {
  const DeviceAlertsPage({super.key});

  @override
  State<DeviceAlertsPage> createState() => _DeviceAlertsPageState();
}

class _DeviceAlertsPageState extends State<DeviceAlertsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  bool bluetoothEnabled = false;
  bool deviceAlertsEnabled = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('device_alerts')
            .get();
        
        if (doc.exists) {
          final data = doc.data()!;
          setState(() {
            bluetoothEnabled = data['bluetooth_enabled'] ?? false;
            deviceAlertsEnabled = data['device_alerts_enabled'] ?? false;
            isLoading = false;
          });
        } else {
          // Create default settings
          await _saveSettings();
          setState(() {
            isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading settings: $e');
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Failed to load settings');
    }
  }

  Future<void> _saveSettings() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('settings')
            .doc('device_alerts')
            .set({
          'bluetooth_enabled': bluetoothEnabled,
          'device_alerts_enabled': deviceAlertsEnabled,
          'updated_at': FieldValue.serverTimestamp(),
        });

        _showSuccessSnackBar('Settings saved successfully');
      }
    } catch (e) {
      print('Error saving settings: $e');
      _showErrorSnackBar('Failed to save settings');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF4CAF50),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFF44336),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFFCE7ED6);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Device & Alerts',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFCE7ED6),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    'App Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Manage your device connections and alert preferences',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildToggleCard(
                    'Bluetooth Connection',
                    'Enable automatic bluetooth device connection',
                    Icons.bluetooth,
                    bluetoothEnabled,
                    purple,
                    (value) {
                      setState(() {
                        bluetoothEnabled = value;
                      });
                      _saveSettings();
                    },
                  ),
                  const SizedBox(height: 20),
                  _buildToggleCard(
                    'Device Alerts',
                    'Receive notifications from connected devices',
                    Icons.notifications_active,
                    deviceAlertsEnabled,
                    purple,
                    (value) {
                      setState(() {
                        deviceAlertsEnabled = value;
                      });
                      _saveSettings();
                    },
                  ),
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.purple.shade200,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.purple.shade600,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Bluetooth connection allows the app to automatically connect to your health monitoring devices. Device alerts will notify you of important health readings and reminders.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.purple.shade700,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 50),
                  Container(
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        Text(
                          'Need Help?',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: () {
                            // Handle contact support
                          },
                          child: const Text(
                            'Contact Support',
                            style: TextStyle(
                              color: Color(0xFFCE7ED6),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildToggleCard(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Color color,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color,
            radius: 25,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: color,
            inactiveThumbColor: Colors.grey.shade400,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }
}