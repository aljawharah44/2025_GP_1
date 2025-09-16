import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import './reminders.dart';
import './home_page.dart';
import './settings.dart';
import './sos_screen.dart';
import './location_permission_screen.dart';

class ContactInfoPage extends StatefulWidget {
  const ContactInfoPage({super.key});

  @override
  State<ContactInfoPage> createState() => _ContactInfoPageState();
}

class _ContactInfoPageState extends State<ContactInfoPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  
  List<Map<String, dynamic>> _contacts = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidSaudiPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    if (cleanPhone.startsWith('+966')) {
      cleanPhone = cleanPhone.substring(4);
      return cleanPhone.length == 9 && RegExp(r'^[5][0-9]{8}$').hasMatch(cleanPhone);
    }
    
    if (cleanPhone.startsWith('966')) {
      cleanPhone = cleanPhone.substring(3);
      return cleanPhone.length == 9 && RegExp(r'^[5][0-9]{8}$').hasMatch(cleanPhone);
    }
    
    if (cleanPhone.startsWith('05')) {
      return cleanPhone.length == 10 && RegExp(r'^05[0-9]{8}$').hasMatch(cleanPhone);
    }
    
    if (cleanPhone.length == 9 && cleanPhone.startsWith('5')) {
      return RegExp(r'^[5][0-9]{8}$').hasMatch(cleanPhone);
    }
    
    return false;
  }

  String _formatPhoneNumber(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    
    if (cleanPhone.startsWith('+966')) {
      return cleanPhone;
    } else if (cleanPhone.startsWith('966')) {
      return '+$cleanPhone';
    } else if (cleanPhone.startsWith('05')) {
      return '+966${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 9 && cleanPhone.startsWith('5')) {
      return '+966$cleanPhone';
    }
    
    return cleanPhone;
  }

  Future<void> _loadContacts() async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return;

      final QuerySnapshot snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .orderBy('name')
          .get();

      setState(() {
        _contacts = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  Future<void> _addContact() async {
    if (_nameController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a name'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_phoneController.text.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a phone number'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!_isValidSaudiPhoneNumber(_phoneController.text.trim())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid Saudi phone number'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      final formattedPhone = _formatPhoneNumber(_phoneController.text.trim());

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .add({
        'name': _nameController.text.trim(),
        'phone': formattedPhone,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _loadContacts();

      if (mounted) {
        Navigator.pop(context);
        _resetForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding contact: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateContact(String contactId, String newName, String newPhone) async {
    if (newName.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a name'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (newPhone.trim().isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a phone number'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!_isValidSaudiPhoneNumber(newPhone.trim())) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid Saudi phone number'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final User? user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      final formattedPhone = _formatPhoneNumber(newPhone.trim());

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactId)
          .update({
        'name': newName.trim(),
        'phone': formattedPhone,
      });

      await _loadContacts();

      if (mounted) {
        Navigator.pop(context);
        _resetForm();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Contact updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating contact: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteContact(String contactId, String contactName) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .doc(contactId)
          .delete();

      await _loadContacts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$contactName deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting contact: $e')),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _nameController.clear();
      _phoneController.clear();
      _isUploading = false;
    });
  }

  void _showDeleteConfirmation(String contactId, String contactName) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Contact',
            style: TextStyle(
              color: Color(0xFF6B1D73),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$contactName"?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deleteContact(contactId, contactName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B1D73),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Map<String, dynamic>> get _filteredContacts {
    if (_searchQuery.isEmpty) return _contacts;
    return _contacts
        .where(
          (contact) =>
              contact['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
              contact['phone'].toString().toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Container(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(
                      top: 40,
                      left: 16,
                      right: 16,
                      bottom: 30,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(74, 243, 210, 247),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(65),
                        bottomRight: Radius.circular(65),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          offset: const Offset(0, 3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          height: 40,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Center(
                                child: Text(
                                  'Emergency Contact Info',
                                  style: TextStyle(
                                    color: Color(0xFFB14ABA),
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                top: 0,
                                child: GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: const Icon(
                                    Icons.arrow_back_ios,
                                    color: Color(0xFFB14ABA),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 25),
                        Center(
                          child: Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            height: 35,
                            decoration: BoxDecoration(
                              color: const Color(0x38B14ABA),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search,
                                  color: Color(0xFFB14ABA),
                                  size: 25,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (value) =>
                                        setState(() => _searchQuery = value),
                                    decoration: const InputDecoration(
                                      hintText: "Search",
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(
                                        color: Color(0xFFB14ABA),
                                      ),
                                      contentPadding: EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFFB14ABA),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 23),
                  
                  _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(50.0),
                          child: CircularProgressIndicator(
                            color: Color(0xFFB14ABA),
                          ),
                        )
                      : _filteredContacts.isEmpty && _searchQuery.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.search_off,
                                  size: 40,
                                  color: Colors.grey.withOpacity(0.6),
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                  "No contacts found matching your search",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _contacts.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.contacts_outlined,
                                  size: 40,
                                  color: const Color(0xFFB14ABA).withOpacity(0.6),
                                ),
                                const SizedBox(height: 15),
                                const Text(
                                  "You haven't added contacts yet",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: _filteredContacts.map((contact) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 20),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF640B6D),
                                      Color(0xFFCEA5D2),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Stack(
                                  children: [
                                    ListTile(
                                      contentPadding: const EdgeInsets.all(16),
                                      leading: CircleAvatar(
                                        radius: 30,
                                        backgroundColor: Colors.white,
                                        child: Text(
                                          contact['name']?.toString().substring(0, 1).toUpperCase() ?? '?',
                                          style: const TextStyle(
                                            color: Color(0xFF6B1D73),
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        contact['name']?.toString() ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        contact['phone']?.toString() ?? 'No phone',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          GestureDetector(
                                            onTap: () => _showEditDialog(
                                              contact['id'],
                                              contact['name']?.toString() ?? 'Unknown',
                                              contact['phone']?.toString() ?? '',
                                            ),
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.edit,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _showDeleteConfirmation(
                                              contact['id'],
                                              contact['name']?.toString() ?? 'Unknown',
                                            ),
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(0.2),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                  const SizedBox(height: 80), // Space for bottom navigation
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // Set to 0 for Home since this is accessed from Home
        selectedItemColor: const Color(0xFFB14ABA),
        unselectedItemColor: Colors.black,
        backgroundColor: Colors.grey.shade200,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
        type: BottomNavigationBarType.fixed,
        onTap: (index) async {
          if (index == 0) {
            // Fixed: Navigate to HomePage instead of popping to first route
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const RemindersPage()),
            );
          } else if (index == 2) {
            final user = _auth.currentUser;
            if (user != null) {
              final doc = await _firestore
                  .collection('users')
                  .doc(user.uid)
                  .get();
              final data = doc.data();
              final permissionGranted =
                  data?['location_permission_granted'] ?? false;
              if (!permissionGranted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LocationPermissionScreen(
                      onPermissionGranted: () async {
                        await _firestore
                            .collection('users')
                            .doc(user.uid)
                            .update({'location_permission_granted': true});
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SosScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                );
              } else {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SosScreen()),
                );
              }
            }
          } else if (index == 3) {
            Navigator.pushReplacement(
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
      floatingActionButton: Container(
        width: MediaQuery.of(context).size.width - 32,
        height: 55,
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: FloatingActionButton.extended(
          onPressed: () => _showAddDialog(),
          backgroundColor: const Color(0xFF6B1D73),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          label: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Add Contact',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showAddDialog() {
    _resetForm();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24),
                      const Text(
                        "Add Contact",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B1D73),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _resetForm();
                          Navigator.pop(context);
                        },
                        child: const Icon(Icons.close, color: Color(0xFF6B1D73)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: "Enter contact name",
                      hintStyle: const TextStyle(color: Colors.grey),
                      fillColor: Colors.grey.shade100,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\(\)\s]')),
                    ],
                    decoration: InputDecoration(
                      hintText: "05xxxxxxxx or +966xxxxxxxxx",
                      hintStyle: const TextStyle(color: Colors.grey),
                      fillColor: Colors.grey.shade100,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Accepted formats: 05xxxxxxxx, +966xxxxxxxxx, 966xxxxxxxxx',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _isUploading
                          ? null
                          : () async {
                              setDialogState(() => _isUploading = true);
                              await _addContact();
                              setDialogState(() => _isUploading = false);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B1D73),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              "Add Contact",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(String contactId, String currentName, String currentPhone) {
    _resetForm();
    _nameController.text = currentName;
    _phoneController.text = currentPhone;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 24),
                      const Text(
                        "Edit Contact",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B1D73),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _resetForm();
                          Navigator.pop(context);
                        },
                        child: const Icon(
                          Icons.close,
                          color: Color(0xFF6B1D73),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Name",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: "Enter contact name",
                      hintStyle: const TextStyle(color: Colors.grey),
                      fillColor: Colors.grey.shade100,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Phone Number",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\(\)\s]')),
                    ],
                    decoration: InputDecoration(
                      hintText: "05xxxxxxxx or +966xxxxxxxxx",
                      hintStyle: const TextStyle(color: Colors.grey),
                      fillColor: Colors.grey.shade100,
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Accepted formats: 05xxxxxxxx, +966xxxxxxxxx, 966xxxxxxxxx',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _isUploading
                          ? null
                          : () async {
                              setDialogState(() => _isUploading = true);
                              await _updateContact(
                                contactId,
                                _nameController.text.trim(),
                                _phoneController.text.trim(),
                              );
                              setDialogState(() => _isUploading = false);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B1D73),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: Colors.grey.shade300,
                      ),
                      child: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Text(
                              "Update Contact",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}