import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:telephony/telephony.dart';
import 'contact_info_page.dart';

class LocationSelectionPage extends StatefulWidget {
  const LocationSelectionPage({super.key});

  @override
  State<LocationSelectionPage> createState() => _LocationSelectionPageState();
}

class _LocationSelectionPageState extends State<LocationSelectionPage>
    with WidgetsBindingObserver {
  
  // Telephony instance for SMS
  final Telephony _telephony = Telephony.instance;
  
  // Controllers
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _streetController = TextEditingController();

  // Location variables
  GoogleMapController? _mapController;
  LatLng? _currentLatLng;
  final Set<Marker> _markers = <Marker>{};

  // State variables
  bool _isLocationLoaded = false;
  bool _isLoadingLocation = false;
  String _locationStatus = 'Tap to get location';
  bool _hasLocationPermission = false;
  double _currentAccuracy = 0.0;
  bool _isSendingLocation = false;

  // User data - Updated to properly handle Firestore updates
  String _userName = 'User';
  bool _isLoadingUserData = true;
  List<Map<String, dynamic>> _contacts = [];
  StreamSubscription<DocumentSnapshot>? _userDataSubscription;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Map controller
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();

  // Initial camera position - Riyadh
  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: LatLng(24.7136, 46.6753),
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSMS();
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userDataSubscription?.cancel(); // Cancel Firestore listener
    _cityController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _checkInitialPermissions();
    }
  }

  // Initialize SMS functionality
  void _initializeSMS() {
    try {
      debugPrint('Telephony SMS initialized successfully');
    } catch (e) {
      debugPrint('Error initializing telephony SMS: $e');
    }
  }

  Future<void> _initializeApp() async {
    try {
      await _loadUserData();
      await _loadUserContacts();
      await _checkInitialPermissions();
    } catch (e) {
      debugPrint('App initialization error: $e');
      if (mounted) {
        setState(() {
          _isLoadingUserData = false;
          _locationStatus = 'Initialization failed';
        });
      }
    }
  }

  // UPDATED: Enhanced user data loading with real-time Firestore listener - same as SOS screen
  Future<void> _loadUserData() async {
    if (!mounted) return;
    try {
      final User? user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _userName = 'Guest';
            _isLoadingUserData = false;
          });
        }
        return;
      }

      // Set up real-time listener for user data updates - same as SOS screen
      _userDataSubscription = _firestore
          .collection('users')
          .doc(user.uid)
          .snapshots()
          .listen(
        (DocumentSnapshot userDoc) {
          if (mounted) {
            if (userDoc.exists) {
              final Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
              setState(() {
                // Use the same field priority as SOS screen - 'full_name' first
                _userName = userData?['full_name'] as String? ??
                    userData?['displayName'] as String? ??
                    userData?['name'] as String? ??
                    userData?['firstName'] as String? ??
                    userData?['fullName'] as String? ??
                    user.displayName ??
                    user.email?.split('@')[0] ??
                    'User';
                _isLoadingUserData = false;
              });
              debugPrint('User name updated from Firestore: $_userName');
            } else {
              _setUserNameFromAuth(user);
            }
          }
        },
        onError: (error) {
          debugPrint('Firestore user data listener error: $error');
          if (mounted) {
            final User? currentUser = _auth.currentUser;
            if (currentUser != null) {
              _setUserNameFromAuth(currentUser);
            } else {
              setState(() {
                _userName = 'User';
                _isLoadingUserData = false;
              });
            }
          }
        },
      );

      // Also do an initial fetch with timeout for immediate data
      try {
        final DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 8));

        if (mounted && userDoc.exists) {
          final Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;
          setState(() {
            // Use the same field priority as SOS screen - 'full_name' first
            _userName = userData?['full_name'] as String? ??
                userData?['displayName'] as String? ??
                userData?['name'] as String? ??
                userData?['firstName'] as String? ??
                userData?['fullName'] as String? ??
                user.displayName ??
                user.email?.split('@')[0] ??
                'User';
            _isLoadingUserData = false;
          });
        }
      } catch (e) {
        debugPrint('Initial user data fetch timeout/error: $e');
        // Fallback to auth data if Firestore fails
        _setUserNameFromAuth(user);
      }
    } catch (e) {
      debugPrint('Load user data error: $e');
      if (mounted) {
        final User? user = _auth.currentUser;
        if (user != null) {
          _setUserNameFromAuth(user);
        } else {
          setState(() {
            _userName = 'User';
            _isLoadingUserData = false;
          });
        }
      }
    }
  }

  void _setUserNameFromAuth(User user) {
    if (mounted) {
      setState(() {
        _userName = user.displayName ??
            user.email?.split('@')[0] ??
            'User';
        _isLoadingUserData = false;
      });
    }
  }

  Future<void> _loadUserContacts() async {
    if (!mounted) return;
    try {
      final User? user = _auth.currentUser;
      if (user == null) return;

      final QuerySnapshot contactsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('contacts')
          .get()
          .timeout(const Duration(seconds: 8));

      if (mounted) {
        setState(() {
          _contacts = contactsSnapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return data;
          }).toList();
        });
        debugPrint('Loaded ${_contacts.length} contacts for SMS functionality');
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    }
  }

  // SMS sending using telephony package
  Future<bool> _sendLocationSMS() async {
    if (_currentLatLng == null || _contacts.isEmpty) {
      _showSnackBar(
        _contacts.isEmpty
            ? 'No contacts found. Add contacts first.'
            : 'No location available to share',
        isError: true,
      );
      return false;
    }

    // Check SMS permissions first
    bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != true) {
      _showSnackBar('SMS permissions required to send emergency messages', isError: true);
      return false;
    }

    setState(() {
      _isSendingLocation = true;
    });

    try {
      final String locationText = '🚨 EMERGENCY: My current location: ${_cityController.text}, ${_streetController.text}';
      final String mapsUrl = 'https://maps.google.com/?q=${_currentLatLng!.latitude},${_currentLatLng!.longitude}';
      final String messageBody = '$locationText\n\n📍 View on map: $mapsUrl\n\nSent from Emergency Location Tracker - $_userName';

      int successCount = 0;
      int failCount = 0;

      for (var contact in _contacts) {
        try {
          final String phoneNumber = contact['phone'] ?? '';
          if (phoneNumber.isNotEmpty) {
            // Clean phone number - remove any non-digit characters except +
            String cleanPhoneNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
            
            // Ensure proper format for Saudi Arabia numbers
            if (cleanPhoneNumber.startsWith('05')) {
              cleanPhoneNumber = '+966${cleanPhoneNumber.substring(1)}';
            } else if (cleanPhoneNumber.startsWith('5') && cleanPhoneNumber.length == 9) {
              cleanPhoneNumber = '+966$cleanPhoneNumber';
            }
            
            debugPrint('Sending SMS to ${contact['name']} at $cleanPhoneNumber');
            
            // Send SMS using telephony package
            await _telephony.sendSms(
              to: cleanPhoneNumber,
              message: messageBody,
            );
            
            debugPrint('SMS sent to ${contact['name']}');
            successCount++;
            
            // Small delay between SMS sends to avoid rate limiting
            await Future.delayed(const Duration(milliseconds: 1000));
            
          } else {
            failCount++;
            debugPrint('Empty phone number for ${contact['name']}');
          }
        } catch (e) {
          failCount++;
          debugPrint('Error sending SMS to ${contact['name']}: $e');
        }
      }

      setState(() {
        _isSendingLocation = false;
      });

      // Show result and return success status
      if (successCount > 0) {
        _showSnackBar(
          '✅ Emergency location sent to $successCount contact(s)${failCount > 0 ? ' ($failCount failed)' : ''}',
          isError: false,
        );
        return true;
      } else {
        _showSnackBar('❌ Failed to send location to contacts. Please check SMS permissions and try again.', isError: true);
        return false;
      }
    } catch (e) {
      setState(() {
        _isSendingLocation = false;
      });
      debugPrint('Error in SMS sending: $e');
      _showSnackBar('Error sending location: ${e.toString()}', isError: true);
      return false;
    }
  }

  // Enhanced confirmation dialog with better SMS info
  Future<void> _confirmAndSendLocation() async {
    if (_contacts.isEmpty) {
      _showSnackBar('No contacts found. Add contacts first.', isError: true);
      return;
    }

    final bool? shouldSend = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.emergency_share, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text(
              'Send Emergency SMS',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will send an emergency SMS with your location to all your contacts.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.location_on, size: 16, color: Colors.blue),
                      SizedBox(width: 4),
                      Text('Location:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  Text(
                    '${_cityController.text}, ${_streetController.text}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Recipients:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              height: 80,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ListView.builder(
                itemCount: _contacts.length > 3 ? 3 : _contacts.length,
                itemBuilder: (context, index) {
                  final contact = _contacts[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Row(
                      children: [
                        const Icon(Icons.person, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${contact['name']} (${contact['phone']})',
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_contacts.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '... and ${_contacts.length - 3} more contacts',
                  style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SMS charges may apply depending on your plan',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.send, size: 18),
            label: const Text('Send Emergency SMS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );

    if (shouldSend == true) {
      // Send SMS directly and show result
      final bool smsSuccess = await _sendLocationSMS();
      if (mounted) {
        Navigator.of(context).pop(smsSuccess); // Return SMS success status to parent
      }
    }
  }

  Future<void> _checkInitialPermissions() async {
    if (!mounted) return;
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final LocationPermission permission = await Geolocator.checkPermission();

      if (mounted) {
        setState(() {
          _hasLocationPermission = serviceEnabled &&
              (permission == LocationPermission.always ||
                  permission == LocationPermission.whileInUse);
          _locationStatus = _hasLocationPermission
              ? 'Tap "Get Current Location" to find your location'
              : 'Location permission needed';
        });
      }
    } catch (e) {
      debugPrint('Permission check error: $e');
      if (mounted) {
        setState(() {
          _locationStatus = 'Permission check failed';
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    if (_isLoadingLocation || !mounted) return;

    try {
      setState(() {
        _isLoadingLocation = true;
        _locationStatus = 'Checking location services...';
      });

      final bool hasPermissions = await _checkAndRequestPermissions();
      if (!hasPermissions) return;

      setState(() {
        _locationStatus = 'Getting your current location...';
      });

      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 30),
      ).timeout(const Duration(seconds: 35));

      debugPrint('📍 Location: lat=${position.latitude}, lng=${position.longitude}, accuracy=${position.accuracy}m');

      if (mounted && _isValidLocation(position)) {
        await _updateLocationData(position);
      } else if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Location accuracy too low, please try again';
        });
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Failed to get location. Please try again.';
        });
        _showLocationErrorDialog();
      }
    }
  }

  bool _isValidLocation(Position position) {
    if (position.latitude.toStringAsFixed(4) == '37.4220' &&
        position.longitude.toStringAsFixed(4) == '-122.0841') {
      debugPrint('🚫 Detected Google Mountain View fallback location - rejecting');
      return false;
    }
    if (position.accuracy > 100) {
      debugPrint('🚫 Location accuracy too poor: ${position.accuracy}m');
      return false;
    }
    if (position.latitude == 0.0 && position.longitude == 0.0) {
      debugPrint('🚫 Invalid coordinates: 0,0');
      return false;
    }
    return true;
  }

  void _showLocationErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Location Error'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Could not get your location. To improve accuracy:'),
            SizedBox(height: 8),
            Text('• Move to an area with better signal'),
            Text('• Ensure location services are enabled'),
            Text('• Check if location permission is granted'),
            Text('• Try again in a few moments'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openLocationSettings();
            },
            child: const Text('Location Settings'),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkAndRequestPermissions() async {
    if (!mounted) return false;

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Location services are disabled';
        });
        _showLocationServiceDialog();
      }
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      if (mounted) {
        setState(() {
          _locationStatus = 'Requesting location permission...';
        });
      }
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isLoadingLocation = false;
            _locationStatus = 'Location permission denied';
          });
          _showPermissionDialog();
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Location permission permanently denied';
        });
        _showPermissionDialog();
      }
      return false;
    }

    return true;
  }

  Future<void> _updateLocationData(Position position) async {
    if (!mounted) return;
    try {
      final LatLng latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _currentLatLng = latLng;
        _isLocationLoaded = true;
        _isLoadingLocation = false;
        _currentAccuracy = position.accuracy;
        _locationStatus = 'Location found successfully';
        _markers.clear();
        _markers.add(
          Marker(
            markerId: const MarkerId('currentLocation'),
            position: latLng,
            infoWindow: InfoWindow(
              title: 'Current Location',
              snippet: 'Accuracy: ${position.accuracy.toStringAsFixed(0)}m',
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        );
      });

      await _updateMapCamera(latLng);
      await _reverseGeocodeSafely(position);
      await _saveLocationToFirebase(latLng);
    } catch (e) {
      debugPrint('Error updating location data: $e');
      if (mounted) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Error processing location';
        });
      }
    }
  }

  Future<void> _updateMapCamera(LatLng position) async {
    try {
      if (_controller.isCompleted) {
        final GoogleMapController controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: position, zoom: 16),
          ),
        );
      }
    } catch (e) {
      debugPrint('Map camera update error: $e');
    }
  }

  Future<void> _reverseGeocodeSafely(Position position) async {
    if (!mounted) return;
    try {
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 10));

      if (mounted && placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        final String city = place.locality ??
            place.subAdministrativeArea ??
            place.administrativeArea ??
            'Riyadh';
        final String street = place.street ??
            place.thoroughfare ??
            place.subThoroughfare ??
            place.name ??
            'Near $city';

        setState(() {
          _cityController.text = city;
          _streetController.text = street;
        });
        debugPrint('Geocoded address: $city, $street');
      }
    } catch (e) {
      debugPrint('Reverse geocoding error: $e');
      if (mounted) {
        setState(() {
          _cityController.text = 'Riyadh';
          _streetController.text = 'Current Location';
        });
      }
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (_currentLatLng == null) {
      _showSnackBar('No location available to open in maps', isError: true);
      return;
    }

    final double lat = _currentLatLng!.latitude;
    final double lng = _currentLatLng!.longitude;

    try {
      final String url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        final String fallbackUrl = 'https://maps.google.com/?q=$lat,$lng';
        final Uri fallbackUri = Uri.parse(fallbackUrl);
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri);
        } else {
          _showSnackBar('Could not open maps application', isError: true);
        }
      }
    } catch (e) {
      debugPrint('Error opening maps: $e');
      _showSnackBar('Error opening maps: ${e.toString()}', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: Duration(seconds: isError ? 4 : 3),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _saveLocationToFirebase(LatLng latLng) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null) return;

      final Map<String, dynamic> locationData = <String, dynamic>{
        'userId': user.uid,
        'userEmail': user.email,
        'userName': _userName,
        'latitude': latLng.latitude,
        'longitude': latLng.longitude,
        'accuracy': _currentAccuracy,
        'city': _cityController.text.isNotEmpty ? _cityController.text : 'Riyadh',
        'street': _streetController.text.isNotEmpty ? _streetController.text : 'Current Location',
        'timestamp': FieldValue.serverTimestamp(),
        'devicePlatform': Platform.isAndroid ? 'Android' : Platform.isIOS ? 'iOS' : 'Unknown',
        'locationType': 'emergency',
      };

      final WriteBatch batch = _firestore.batch();
      final DocumentReference currentLocationRef = _firestore
          .collection('userLocations')
          .doc(user.uid);
      final DocumentReference historyRef = _firestore
          .collection('userLocations')
          .doc(user.uid)
          .collection('history')
          .doc();

      batch.set(currentLocationRef, {
        'currentLocation': locationData,
        'lastUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      batch.set(historyRef, locationData);
      await batch.commit().timeout(const Duration(seconds: 10));
      debugPrint('Emergency location saved to Firebase successfully');
    } catch (e) {
      debugPrint('Firebase save error: $e');
    }
  }

  void _showLocationServiceDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Location Services Required'),
        content: const Text(
          'This app needs location services to get your current location. Please enable location services in your device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Geolocator.openLocationSettings();
              if (mounted) {
                await _checkInitialPermissions();
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  void _showPermissionDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Location Permission Required'),
        content: const Text(
          'This app needs location permission to get your current location. Please grant the permission to continue.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await Geolocator.openAppSettings();
              if (mounted) {
                await _checkInitialPermissions();
              }
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    final String displayLocation = _isLocationLoaded && _currentLatLng != null
        ? '${_cityController.text}, ${_streetController.text}'
        : _locationStatus;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Top section - UPDATED: Removed emergency icon and made user name purple
          Container(
            width: double.infinity,
            height: 140,
            color: Colors.grey[300],
            padding: EdgeInsets.only(
              top: statusBarHeight + 10,
              left: 20,
              right: 20,
              bottom: 10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hey!',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _isLoadingUserData
                              ? const SizedBox(
                                  width: 100,
                                  height: 20,
                                  child: LinearProgressIndicator(
                                    backgroundColor: Colors.grey,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                                  ),
                                )
                              : Text(
                                  _userName,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.purple, // Same color as SOS screen
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                        ],
                      ),
                    ),
                    // REMOVED: Emergency icon container
                  ],
                ),
              ],
            ),
          ),

          // Bottom sheet
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.of(context).pop(false); // Return false when user cancels
                          },
                          icon: const Icon(Icons.arrow_back),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Emergency Location',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFB14ABA),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 10),

                          // Map container
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                children: [
                                  GoogleMap(
                                    initialCameraPosition: _initialCameraPosition,
                                    myLocationEnabled: false,
                                    myLocationButtonEnabled: false,
                                    markers: _markers,
                                    onMapCreated: (GoogleMapController controller) {
                                      if (!_controller.isCompleted) {
                                        _controller.complete(controller);
                                        _mapController = controller;
                                      }
                                    },
                                    buildingsEnabled: true,
                                    zoomControlsEnabled: false,
                                    mapType: MapType.normal,
                                    liteModeEnabled: false,
                                  ),
                                  if (_currentLatLng != null && _isLocationLoaded)
                                    Positioned(
                                      top: 10,
                                      right: 10,
                                      child: Material(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        elevation: 2,
                                        child: InkWell(
                                          onTap: _openInGoogleMaps,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            padding: const EdgeInsets.all(8),
                                            child: const Icon(
                                              Icons.open_in_new,
                                              color: Colors.blue,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_isLoadingLocation)
                                    Container(
                                      color: Colors.black54,
                                      child: const Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            CircularProgressIndicator(
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                            SizedBox(height: 12),
                                            Text(
                                              'Getting your location...',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Get location button
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                                  icon: _isLoadingLocation
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Icon(Icons.my_location, size: 18),
                                  label: Text(
                                    _isLoadingLocation
                                        ? 'Getting Location...'
                                        : 'Get Current Location',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Location display with accuracy
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _isLocationLoaded ? Colors.blue[50] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isLocationLoaded ? Colors.blue[200]! : Colors.grey[200]!,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _isLocationLoaded ? Icons.location_on : Icons.location_off,
                                      color: _isLocationLoaded ? Colors.blue : Colors.grey[600],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        displayLocation,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: _isLocationLoaded ? Colors.black87 : Colors.grey[600],
                                          fontWeight: _isLocationLoaded ? FontWeight.w500 : FontWeight.normal,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                if (_isLocationLoaded && _currentAccuracy > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, left: 32),
                                    child: Text(
                                      'Accuracy: ${_currentAccuracy.toStringAsFixed(0)}m',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // City and Street fields
                          _buildTextField(_cityController, 'City', isHighlighted: true),
                          const SizedBox(height: 12),
                          _buildTextField(_streetController, 'Street'),

                          const SizedBox(height: 16),

                          if (_contacts.isNotEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFB14ABA).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFB14ABA).withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.contacts, color: Color(0xFFB14ABA), size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Ready to send emergency SMS to ${_contacts.length} contact(s)',
                                      style: const TextStyle(
                                        color: Color(0xFFB14ABA),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.orange[200]!),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.contact_phone, color: Colors.orange, size: 20),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'Add contacts to send emergency location via SMS',
                                      style: TextStyle(
                                        color: Colors.orange,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 8),

                          // Emergency confirm button or Add Contact button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: (_isLocationLoaded && !_isLoadingLocation && !_isSendingLocation)
                                  ? () async {
                                      // If no contacts, navigate to contact info page
                                      if (_contacts.isEmpty) {
                                        final result = await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (_) => const ContactInfoPage()),
                                        );
                                        // Reload contacts after returning from contact page
                                        await _loadUserContacts();
                                        return;
                                      }

                                      // If contacts exist, proceed with location confirmation
                                      try {
                                        // Save location to Firebase first
                                        if (_currentLatLng != null) {
                                          await _saveLocationToFirebase(_currentLatLng!);
                                        }
                                        // Show confirmation dialog and send SMS
                                        await _confirmAndSendLocation();
                                      } catch (e) {
                                        debugPrint('Error confirming emergency location: $e');
                                        if (mounted) {
                                          _showSnackBar('Error confirming location', isError: true);
                                          Navigator.of(context).pop(false);
                                        }
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: (_isLocationLoaded && !_isLoadingLocation && !_isSendingLocation)
                                    ? const Color(0xFFB14ABA)
                                    : Colors.grey[400],
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                              child: _isSendingLocation
                                  ? const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Sending Emergency SMS...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isLoadingLocation
                                              ? Icons.hourglass_empty
                                              : _isLocationLoaded
                                                  ? (_contacts.isEmpty
                                                      ? Icons.person_add
                                                      : Icons.emergency_share)
                                                  : Icons.location_searching,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isLoadingLocation
                                              ? 'Loading...'
                                              : _isLocationLoaded
                                                  ? (_contacts.isEmpty
                                                      ? 'Add Emergency Contacts'
                                                      : 'Send Emergency SMS')
                                                  : 'Get Location First',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, {bool isHighlighted = false}) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isHighlighted ? Colors.purple : Colors.grey[300]!,
          width: isHighlighted ? 2 : 1,
        ),
        color: Colors.white,
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}