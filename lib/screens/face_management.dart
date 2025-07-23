import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

class FaceManagementPage extends StatefulWidget {
  const FaceManagementPage({super.key});

  @override
  State<FaceManagementPage> createState() => _FaceManagementPageState();
}

class _FaceManagementPageState extends State<FaceManagementPage> {
  File? _selectedImage;
  final TextEditingController _nameController = TextEditingController();

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
        ), // ⬅️ هذا يجعل الحوار أعرض
        child: Container(
          width: double.infinity, // ⬅️ عرض كامل داخل المساحة المتاحة
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ⬅️ السطر العلوي فيه العنوان والأكس
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 24), // مساحة فارغة للتوازن
                  const Text(
                    "Add Person",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B1D73),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: Color(0xFF6B1D73)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              const Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),

              // ⬅️ إدخال الاسم
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

              const Text(
                "Upload Face Photo",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),

              // ⬅️ رفع الصورة
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 100, // ⬅️ قللت الارتفاع من 150 إلى 100
                  padding: const EdgeInsets.all(
                    12,
                  ), // ⬅️ قللت الـ padding من 16 إلى 12
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade300),
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
                              height: 30, // ⬅️ قللت الحجم من 40 إلى 30
                              color: Color(0xFF6B1D73),
                            ),
                            const SizedBox(
                              height: 8,
                            ), // ⬅️ قللت المسافة من 10 إلى 8
                            const Text(
                              "Click to Upload Photo",
                              style: TextStyle(
                                color: Color(0xFF6B1D73),
                                fontWeight: FontWeight.w500,
                                fontSize: 12, // ⬅️ أضفت حجم خط أصغر
                              ),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // ⬅️ زر Add
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _selectedImage = null;
                      _nameController.clear();
                    });
                  },
                  icon: const Icon(
                    Icons.add,
                    color: Colors.white,
                    size: 20,
                  ), // ⬅️ أيقونة أكبر
                  label: const Text(
                    "Add",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16, // ⬅️ خط أكبر
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B1D73),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 25, // ⬅️ زدت العرض من 24 إلى 32
                      vertical: 13, // ⬅️ زدت الارتفاع من 12 إلى 14
                    ),
                  ),
                ),
              ),
            ],
          ),
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
          color: const Color.fromARGB(74, 243, 210, 247),
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
                                const Expanded(
                                  child: TextField(
                                    decoration: InputDecoration(
                                      hintText: "Search",
                                      border: InputBorder.none,
                                      hintStyle: TextStyle(
                                        color: Color(0xFFB14ABA),
                                      ),
                                      contentPadding: EdgeInsets.only(
                                        bottom: 10,
                                      ),
                                    ),
                                    style: TextStyle(color: Color(0xFFB14ABA)),
                                  ),
                                ),
                                Image.asset(
                                  'assets/images/filter.png',
                                  height: 22,
                                  width: 22,
                                  color: Color(0xFFB14ABA),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 23),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: List.generate(5, (index) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF640B6D), Color(0xFFCEA5D2)],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: const CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.person, color: Colors.grey),
                            ),
                            title: const Text(
                              "Michael Davidson,\nM.D.",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text(
                              "Solar Dermatology",
                              style: TextStyle(color: Colors.white70),
                            ),
                            onTap: () {},
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFFB14ABA),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(
            icon: Transform.translate(
              offset: const Offset(0, -10),
              child: GestureDetector(
                onTap: _showAddDialog,
                child: const Icon(
                  Icons.add_circle,
                  size: 68,
                  color: Colors.black,
                ),
              ),
            ),
            label: '',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.warning),
            label: 'Emergency',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Setting',
          ),
        ],
        onTap: (index) {},
      ),
    );
  }
}
