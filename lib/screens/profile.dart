import 'dart:convert';
import 'dart:io';

import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:dropdown_search/dropdown_search.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _image;
  final picker = ImagePicker();

  String? selectedCountryCode;
  String? selectedCountryName;
  String? selectedCity;
  String? address;

  List<String> cities = [];

  Future<void> _getImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _image = File(pickedFile.path));
    }
  }

  Future<void> fetchCities(String countryCode) async {
    final username = 'fajer_mh';
    final url = Uri.parse(
      'http://api.geonames.org/searchJSON?country=$countryCode&featureClass=P&maxRows=1000&username=$username',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<String> fetchedCities = (data['geonames'] as List)
            .where((item) => item['fcode'] == 'PPLA' || item['fcode'] == 'PPLC')
            .map((item) => item['name'].toString())
            .toSet()
            .toList();

        setState(() {
          cities = fetchedCities;
        });
      } else {
        setState(() {
          cities = [];
        });
      }
    } catch (e) {
      setState(() {
        cities = [];
      });
    }
  }

  Future<void> _getCurrentLocationAndFill() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.deniedForever ||
            permission == LocationPermission.denied)
          return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        setState(() {
          selectedCountryName = place.country;
          selectedCountryCode = place.isoCountryCode;
          selectedCity = place.locality ?? place.subAdministrativeArea;
          address =
              "${place.street ?? ''}, ${place.subLocality ?? ''}, ${place.administrativeArea ?? ''}";
        });

        if (selectedCountryCode != null) {
          fetchCities(selectedCountryCode!);
        }
      }
    } catch (e) {
      print("Location error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),

            // بداية نفس الكود السابق تمامًا...
            // لا حاجة لإعادة لصق الجزء العلوي لأنك وضعت الكود كاملاً وسليم.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // ✅ عنوان Personal Details
                  const Text(
                    "Personal Details",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  _buildTextField(label: "Name"),
                  _buildTextField(label: "Email Address"),
                  _buildTextField(label: "Phone Number"),
                  const SizedBox(height: 20),

                  // ✅ عنوان Address Details + زر or Google Map يمين
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Address Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: _getCurrentLocationAndFill,
                        child: const Text(
                          "or Use Current Location",
                          style: TextStyle(
                            color: Color(0xFF6B1D73),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // باقي الحقول كما هي بالضبط
                  const Text(
                    "Country",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      showCountryPicker(
                        context: context,
                        showPhoneCode: false,
                        onSelect: (Country country) {
                          setState(() {
                            selectedCountryCode = country.countryCode;
                            selectedCountryName = country.name;
                            selectedCity = null;
                            cities = [];
                          });
                          fetchCities(country.countryCode);
                        },
                      );
                    },
                    child: AbsorbPointer(
                      child: DropdownButtonFormField<String>(
                        value: selectedCountryName,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        hint: Text(
                          "Please select your Country",
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            fontSize: 13,
                            color: Colors.black.withOpacity(0.5),
                          ),
                        ),
                        items: selectedCountryName != null
                            ? [
                                DropdownMenuItem(
                                  value: selectedCountryName,
                                  child: Text(selectedCountryName!),
                                ),
                              ]
                            : [],
                        onChanged: (_) {},
                        icon: const Icon(Icons.arrow_drop_down),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    "City",
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  DropdownSearch<String>(
                    key: ValueKey(selectedCountryCode),
                    items: cities,
                    selectedItem: selectedCity,
                    enabled: cities.isNotEmpty,
                    popupProps: PopupProps.bottomSheet(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Search City...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                      containerBuilder: (context, popupWidget) {
                        return Container(
                          color: Colors.white,
                          child: popupWidget,
                        );
                      },
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                      ),
                      emptyBuilder: (context, _) =>
                          const Center(child: Text("No data found")),
                    ),
                    dropdownDecoratorProps: DropDownDecoratorProps(
                      dropdownSearchDecoration: InputDecoration(
                        hintText: "Please select your City",
                        hintStyle: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                          color: Colors.black.withOpacity(0.5),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                    onChanged: (val) => setState(() => selectedCity = val),
                  ),

                  const SizedBox(height: 12),
                  _buildTextField(label: "Address", initialValue: address),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B1D73),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      "Save",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, String? initialValue}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: initialValue != null
              ? TextEditingController(text: initialValue)
              : null,
          decoration: InputDecoration(
            hintText: label == "Address" ? "Enter your address" : null,
            hintStyle: TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.black.withOpacity(0.5),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHeader() {
    return Stack(
      children: [
        ClipPath(
          clipper: WaveClipper(),
          child: Container(
            height: 260,
            decoration: const BoxDecoration(color: Color(0xFF6B1D73)),
            child: Stack(
              children: [
                Positioned(
                  top: -12,
                  left: -20,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.22),
                    radius: 45,
                  ),
                ),
                Positioned(
                  top: 120,
                  right: -15,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.22),
                    radius: 40,
                  ),
                ),
                Positioned(
                  bottom: 110,
                  left: 60,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.22),
                    radius: 15,
                  ),
                ),
                Positioned(
                  bottom: 210,
                  left: 240,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withOpacity(0.22),
                    radius: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 24,
          left: 6,
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 40),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const Positioned(
          top: 30,
          left: 0,
          right: 0,
          child: Center(
            child: Text(
              "My Profile",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned(
          top: 70,
          left: MediaQuery.of(context).size.width / 2 - 45,
          child: Stack(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundColor: Colors.grey[300],
                backgroundImage: _image != null
                    ? FileImage(_image!)
                    : const AssetImage('assets/images/profileimg.jpg')
                          as ImageProvider,
              ),
              Positioned(
                bottom: 0,
                right: 5,
                child: GestureDetector(
                  onTap: _getImage,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(0xFF007AFF),
                      child: Icon(Icons.edit, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 20);
    var firstStart = Offset(size.width / 4, size.height - 130);
    var firstEnd = Offset(size.width / 2, size.height - 70);
    path.quadraticBezierTo(
      firstStart.dx,
      firstStart.dy,
      firstEnd.dx,
      firstEnd.dy,
    );
    var secondStart = Offset(size.width * 3 / 4, size.height);
    var secondEnd = Offset(size.width, size.height - 120);
    path.quadraticBezierTo(
      secondStart.dx,
      secondStart.dy,
      secondEnd.dx,
      secondEnd.dy,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
