import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'home_page.dart'; // ← للتنقل لصفحة الهوم

class FaceManagementPage extends StatefulWidget {
  const FaceManagementPage({super.key});

  @override
  State<FaceManagementPage> createState() => _FaceManagementPageState();
}

class _FaceManagementPageState extends State<FaceManagementPage> {
  File? _selectedImage;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _people = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('people')
          .orderBy('createdAt', descending: true)
          .get();

      setState(() {
        _people = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading people: $e')));
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));

      // Show notification that image was selected
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Photo selected successfully!'),
          backgroundColor: Color(0xFF6B1D73),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _addPerson() async {
    if (_nameController.text.trim().isEmpty || _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide both name and photo')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      // Upload image to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('photos')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await storageRef.putFile(_selectedImage!);
      final photoUrl = await uploadTask.ref.getDownloadURL();

      // Save person data to Firestore
      final personData = {
        'name': _nameController.text.trim(),
        'photoUrl': photoUrl,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('people')
          .add(personData);

      // Reload the people list
      await _loadPeople();

      // Close dialog and reset state
      Navigator.pop(context);
      _resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Person added successfully!')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error adding person: $e')));
    }
  }

  void _resetForm() {
    setState(() {
      _selectedImage = null;
      _nameController.clear();
      _isUploading = false;
    });
  }

  Future<void> _deletePerson(
    String personId,
    String personName,
    String? photoUrl,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Delete from Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('people')
          .doc(personId)
          .delete();

      // Delete image from Firebase Storage if exists
      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(photoUrl).delete();
        } catch (storageError) {
          // Image might already be deleted or not exist, continue anyway
          print('Storage deletion error: $storageError');
        }
      }

      // Reload the people list
      await _loadPeople();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$personName deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting person: $e')));
    }
  }

  Future<void> _updatePerson(
    String personId,
    String newName,
    File? newImage,
    String? oldPhotoUrl,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUploading = true);

    try {
      String? photoUrl = oldPhotoUrl;

      // If there's a new image, upload it
      if (newImage != null) {
        // Delete old image if exists
        if (oldPhotoUrl != null && oldPhotoUrl.isNotEmpty) {
          try {
            await FirebaseStorage.instance.refFromURL(oldPhotoUrl).delete();
          } catch (e) {
            print('Error deleting old image: $e');
          }
        }

        // Upload new image
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('users')
            .child(user.uid)
            .child('photos')
            .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

        final uploadTask = await storageRef.putFile(newImage);
        photoUrl = await uploadTask.ref.getDownloadURL();
      }

      // Update person data in Firestore
      final updateData = <String, dynamic>{'name': newName.trim()};

      if (photoUrl != null) {
        updateData['photoUrl'] = photoUrl;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('people')
          .doc(personId)
          .update(updateData);

      // Reload the people list
      await _loadPeople();

      // Close dialog and reset state
      Navigator.pop(context);
      _resetForm();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Person updated successfully!')),
      );
    } catch (e) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating person: $e')));
    }
  }

  void _showDeleteConfirmation(
    String personId,
    String personName,
    String? photoUrl,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Delete Person',
            style: TextStyle(
              color: Color(0xFF6B1D73),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$personName"',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                await _deletePerson(personId, personName, photoUrl);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF6B1D73),
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
          ],
        );
      },
    );
  }

  void _showEditDialog(
    String personId,
    String currentName,
    String? currentPhotoUrl,
  ) {
    // Reset and set current values
    _selectedImage = null;
    _nameController.text = currentName;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24),
                    const Text(
                      "Edit Person",
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
                const Text(
                  "Name",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: "Enter name",
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
                Row(
                  children: [
                    const Text(
                      "Update Photo (Optional)",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B1D73),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "✓ New Photo Selected",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () async {
                    await _pickImage();
                    setDialogState(() {}); // Refresh dialog state
                  },
                  child: Container(
                    width: double.infinity,
                    height: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedImage != null
                          ? const Color(0xFFF8F4F9)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedImage != null
                            ? const Color(0xFF6B1D73)
                            : Colors.grey.shade300,
                        width: _selectedImage != null ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _selectedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Show current photo if exists, otherwise show upload icon
                              if (currentPhotoUrl != null) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    currentPhotoUrl,
                                    height: 40,
                                    width: 40,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Current Photo - Tap to Change",
                                  style: TextStyle(
                                    color: Color(0xFF6B1D73),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ] else ...[
                                Image.asset(
                                  'assets/images/upload_icon.png',
                                  height: 30,
                                  color: Color(0xFF6B1D73),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Click to Upload New Photo",
                                  style: TextStyle(
                                    color: Color(0xFF6B1D73),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6B1D73),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "New Photo Selected",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "New Photo Selected - Tap to Change",
                                style: TextStyle(
                                  color: Color(0xFF6B1D73),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : () async {
                            if (_nameController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please provide a name'),
                                ),
                              );
                              return;
                            }

                            setDialogState(
                              () => _isUploading = true,
                            ); // Show loading
                            await _updatePerson(
                              personId,
                              _nameController.text.trim(),
                              _selectedImage,
                              currentPhotoUrl,
                            );
                            setDialogState(
                              () => _isUploading = false,
                            ); // Hide loading
                          },
                    icon: _isUploading
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
                        : const Icon(Icons.edit, color: Colors.white, size: 20),
                    label: Text(
                      _isUploading ? "Updating..." : "Update",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B1D73),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> get _filteredPeople {
    if (_searchQuery.isEmpty) return _people;
    return _people
        .where(
          (person) =>
              person['name'].toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  void _showAddDialog() {
    // Reset the state when opening the dialog
    _resetForm();

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 24),
                    const Text(
                      "Add Person",
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
                const Text(
                  "Name",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: "Enter name",
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
                Row(
                  children: [
                    const Text(
                      "Upload Face Photo",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (_selectedImage != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B1D73),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "✓ Photo Selected",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                GestureDetector(
                  onTap: () async {
                    await _pickImage();
                    setDialogState(() {}); // Refresh dialog state
                  },
                  child: Container(
                    width: double.infinity,
                    height: 100,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _selectedImage != null
                          ? const Color(0xFFF8F4F9)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _selectedImage != null
                            ? const Color(0xFF6B1D73)
                            : Colors.grey.shade300,
                        width: _selectedImage != null ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _selectedImage == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/upload_icon.png',
                                height: 30,
                                color: Color(0xFF6B1D73),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Click to Upload Photo",
                                style: TextStyle(
                                  color: Color(0xFF6B1D73),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6B1D73),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  "Photo Selected",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                "Photo Selected - Tap to Change",
                                style: TextStyle(
                                  color: Color(0xFF6B1D73),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading
                        ? null
                        : () async {
                            setDialogState(
                              () => _isUploading = true,
                            ); // Show loading
                            await _addPerson();
                            setDialogState(
                              () => _isUploading = false,
                            ); // Hide loading
                          },
                    icon: _isUploading
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
                        : const Icon(Icons.add, color: Colors.white, size: 20),
                    label: Text(
                      _isUploading ? "Adding..." : "Add",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B1D73),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 25,
                        vertical: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 40,
              color: const Color(0xFFB14ABA).withOpacity(0.6),
            ),
            const SizedBox(height: 15),
            const Text(
              "You haven't added people yet",
              style: TextStyle(fontSize: 16, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
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
                                  'Face Management',
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
                                  onTap: () {
                                    Navigator.pop(context);
                                  },
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
                                    onChanged: (value) {
                                      setState(() => _searchQuery = value);
                                    },
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
                      : _people.isEmpty
                      ? _buildEmptyState()
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: _filteredPeople.map((person) {
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
                                        backgroundImage:
                                            person['photoUrl'] != null
                                            ? NetworkImage(person['photoUrl'])
                                            : null,
                                        child: person['photoUrl'] == null
                                            ? const Icon(
                                                Icons.person,
                                                color: Colors.grey,
                                              )
                                            : null,
                                      ),
                                      title: Text(
                                        person['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      onTap: () {},
                                    ),
                                    // Edit and Delete buttons
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Edit button
                                          GestureDetector(
                                            onTap: () {
                                              _showEditDialog(
                                                person['id'],
                                                person['name'] ?? 'Unknown',
                                                person['photoUrl'],
                                              );
                                            },
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.3),
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
                                          // Delete button (X)
                                          GestureDetector(
                                            onTap: () {
                                              _showDeleteConfirmation(
                                                person['id'],
                                                person['name'] ?? 'Unknown',
                                                person['photoUrl'],
                                              );
                                            },
                                            child: Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.close,
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
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Home
                GestureDetector(
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const HomePage()),
                    );
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home_outlined,
                        size: 26,
                        color: const Color(0xFFB14ABA),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Home',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFB14ABA),
                        ),
                      ),
                    ],
                  ),
                ),
                // Reminders
                GestureDetector(
                  onTap: () {
                    // Handle reminders tap
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 26,
                        color: Colors.black54,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Reminders',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                // Spacer for the center button
                const SizedBox(width: 55),
                // Emergency
                GestureDetector(
                  onTap: () {
                    // Handle emergency tap
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        size: 26,
                        color: Colors.black54,
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Emergency',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                // Settings
                GestureDetector(
                  onTap: () {
                    // Handle settings tap
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings, size: 26, color: Colors.black54),
                      const SizedBox(height: 2),
                      const Text(
                        'Settings',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Elevated black circular button
          Positioned(
            bottom: 25,
            child: GestureDetector(
              onTap: _showAddDialog,
              child: Container(
                width: 55,
                height: 55,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 40),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
