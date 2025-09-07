import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import '../services/face_recognition_service.dart'; 
import 'home_page.dart';
import 'reminders.dart';
import 'sos_screen.dart';
import 'settings.dart';

class FaceManagementPage extends StatefulWidget {
  const FaceManagementPage({super.key});

  @override
  State<FaceManagementPage> createState() => _FaceManagementPageState();
}

class _FaceManagementPageState extends State<FaceManagementPage> {
  File? _selectedImage;
  File? _croppedFaceImage;
  File? _recognitionImage; // الصورة المستخدمة للتعرف
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _people = [];
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isDetectingFace = false;
  bool _isRecognizing = false;
  String _searchQuery = '';
  final _auth = FirebaseAuth.instance;

// Face recognition result
  RecognitionResult? _recognitionResult;
  String? _recognitionMessage;

  @override
  void initState() {
    super.initState();
    _initializeFaceRecognition();
    _loadPeople();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    FaceRecognitionService.dispose();
    super.dispose();
  }

// Initialize face recognition service
  Future<void> _initializeFaceRecognition() async {
    final success = await FaceRecognitionService.initialize();
    if (!success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to initialize face recognition'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      await _loadStoredEmbeddings();
    }
  }

  // Load stored embeddings from Firestore
  Future<void> _loadStoredEmbeddings() async {
  print('Loading embeddings...');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('face_embeddings')
          .doc('embeddings')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        Map<String, List<double>> embeddings = {};
        
        data.forEach((key, value) {
          if (value is List) {
            embeddings[key] = List<double>.from(value);
          }
        });
        
        FaceRecognitionService.loadEmbeddings(embeddings);
      }
    } catch (e) {
      print('Error loading embeddings: $e');
    }
  }

  // Save embeddings to Firestore
  Future<void> _saveEmbeddingsToFirestore() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final embeddings = FaceRecognitionService.getStoredEmbeddings();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('face_embeddings')
          .doc('embeddings')
          .set(embeddings);
    } catch (e) {
      print('Error saving embeddings: $e');
    }
  }

  // Show dialog to choose recognition source
  void _showRecognitionSourceDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.face_retouching_natural, color: Color(0xFF6B1D73)),
              SizedBox(width: 10),
              Text(
                'Recognize Face',
                style: TextStyle(
                  color: Color(0xFF6B1D73),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Choose how you want to capture the face for recognition:'),
              const SizedBox(height: 20),
              
              // Camera Option
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  _recognizeFace(ImageSource.camera);
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B1D73).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6B1D73), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.camera_alt, color: Color(0xFF6B1D73), size: 30),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Take Photo',
                              style: TextStyle(
                                color: Color(0xFF6B1D73),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Capture a new photo using camera',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              
              // Gallery Option
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pop();
                  _recognizeFace(ImageSource.gallery);
                },
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B1D73).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF6B1D73), width: 1),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.photo_library, color: Color(0xFF6B1D73), size: 30),
                      SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose from Gallery',
                              style: TextStyle(
                                color: Color(0xFF6B1D73),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Select an existing photo from your gallery',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
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


// Recognize face from camera or gallery
  Future<void> _recognizeFace(ImageSource source) async {
  final picked = await ImagePicker().pickImage(source: source);
  if (picked == null) return;

  setState(() {
    _isRecognizing = true;
    _recognitionResult = null;
    _recognitionMessage = null;
    _recognitionImage = File(picked.path);
  });

  try {
    final imageFile = File(picked.path);
    
    // استخدم التحسينات الجديدة مع عتبة أقل وخيارات متقدمة
    final result = await FaceRecognitionService.recognizeFace(
      imageFile, 
      threshold: 0.25, // عتبة أقل
      normalizationType: 'arcface',
      useAdaptiveThreshold: true,
    );

    if (result != null) {
      if (result.isMatch) {
        // Find person name from stored people
        final person = _people.firstWhere(
          (p) => p['id'] == result.personId,
          orElse: () => {'name': 'Unknown Person', 'photoUrl': null}
        );
        
        setState(() {
          _recognitionResult = result;
          _recognitionMessage = 'Recognized: ${person['name']} (${(result.similarity * 100).toStringAsFixed(1)}% match, threshold: ${(result.threshold * 100).toStringAsFixed(1)}%)';
        });

        _showRecognitionResult(
          person['name'] ?? 'Unknown', 
          result.similarity,
          person['photoUrl'],
        );
      } else {
        setState(() {
          _recognitionMessage = 'Face detected but no match found (${(result.similarity * 100).toStringAsFixed(1)}% similarity, needed: ${(result.threshold * 100).toStringAsFixed(1)}%)';
        });

        _showNoMatchDialog(imageFile);
      }
    } else {
      setState(() {
        _recognitionMessage = 'No face detected in the image';
        _recognitionImage = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No face detected. Try a clearer photo with better lighting.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  } catch (e) {
    setState(() {
      _recognitionMessage = 'Error during face recognition: $e';
      _recognitionImage = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Face recognition error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    setState(() => _isRecognizing = false);
  }
}

  // Show recognition result dialog with enhanced details
  void _showRecognitionResult(String personName, double similarity, String? personPhotoUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success icon and title
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Face Recognized!',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B1D73),
                  ),
                ),
                const SizedBox(height: 20),

                // Show both images side by side
                Row(
                  children: [
                    // Recognition image (captured/selected)
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Captured Image',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _recognitionImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.file(
                                      _recognitionImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.image, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    
                    // Arrow
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.arrow_forward, color: Colors.green, size: 30),
                    ),
                    
                    // Stored person image
                    Expanded(
                      child: Column(
                        children: [
                          const Text(
                            'Matched Person',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.green, width: 2),
                            ),
                            child: personPhotoUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      personPhotoUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.person, color: Colors.grey),
                                    ),
                                  )
                                : const Icon(Icons.person, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                
                // Person details
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.person, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Person: $personName',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.green),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Confidence: ${(similarity * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.grey),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Minimum required: 60%',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'OK',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showRecognitionSourceDialog(); // Recognize another face
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B1D73),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Recognize Again',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Show no match dialog with option to add the person
  void _showNoMatchDialog(File unrecognizedImage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_search,
                    color: Colors.orange,
                    size: 50,
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'No Match Found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B1D73),
                  ),
                ),
                const SizedBox(height: 15),

                // Show the unrecognized image
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(unrecognizedImage, fit: BoxFit.cover),
                  ),
                ),
                
                const SizedBox(height: 15),
                const Text(
                  'The face was detected but doesn\'t match any stored faces.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                
                if (_recognitionResult != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Highest similarity: ${(_recognitionResult!.similarity * 100).toStringAsFixed(1)}%\n(Required: 60%)',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 20),
                
                const Text(
                  'Would you like to add this person to your collection?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Pre-fill the add dialog with the unrecognized image
                          _showAddDialogWithImage(unrecognizedImage);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B1D73),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'Add Person',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void _showAddDialogWithImage(File imageFile) {
    _resetForm();
    setState(() {
      _selectedImage = imageFile;
    });

    // Detect face in the pre-filled image
    _detectFaceInSelectedImage();

    _showAddDialog();
  }

  // Detect face in selected image
  Future<void> _detectFaceInSelectedImage() async {
    if (_selectedImage == null) return;

    setState(() => _isDetectingFace = true);

    try {
      final faceRect = await detectFace(_selectedImage!);

      if (faceRect != null) {
        final croppedFace = await cropFace(_selectedImage!, faceRect);
        setState(() {
          _croppedFaceImage = croppedFace;
          _isDetectingFace = false;
        });
      } else {
        setState(() => _isDetectingFace = false);
      }
    } catch (e) {
      setState(() => _isDetectingFace = false);
      print('Error detecting face: $e');
    }
  }

  // Face detection function (updated)
  Future<Rect?> detectFace(File imageFile) async {
    return await FaceRecognitionService.detectFaceEnhanced(imageFile);
  }

  // Face cropping function (updated to use img.Image)
  Future<File?> cropFace(File imageFile, Rect rect) async {
    try {
      final croppedImage = await FaceRecognitionService.cropFaceEnhanced(imageFile, rect);
      if (croppedImage == null) return null;

      final croppedFile = File('${imageFile.path}_face.jpg')
        ..writeAsBytesSync(img.encodeJpg(croppedImage));
      return croppedFile;
    } catch (e) {
      print('Error cropping face: $e');
      return imageFile;
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading people: $e')),
        );
      }
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final imageFile = File(picked.path);

      setState(() {
        _isDetectingFace = true;
        _selectedImage = imageFile;
        _croppedFaceImage = null;
      });

      try {
        final faceRect = await detectFace(imageFile);

        if (faceRect != null) {
          final croppedFace = await cropFace(imageFile, faceRect);

          setState(() {
            _croppedFaceImage = croppedFace;
            _isDetectingFace = false;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Face detected and cropped successfully!'),
                backgroundColor: Color(0xFF6B1D73),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          setState(() => _isDetectingFace = false);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No face detected in this image. Please choose a clear face photo.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      } catch (e) {
        setState(() => _isDetectingFace = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error detecting face: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

   Future<void> _addPerson() async {
  if (_nameController.text.trim().isEmpty || _selectedImage == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide both name and photo')),
      );
    }
    return;
  }

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  setState(() => _isUploading = true);

  try {
    final imageToUpload = _croppedFaceImage ?? _selectedImage!;

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(user.uid)
        .child('photos')
        .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

    final uploadTask = await storageRef.putFile(imageToUpload);
    final photoUrl = await uploadTask.ref.getDownloadURL();

    // Add person to Firestore
    final docRef = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('people')
        .add({
      'name': _nameController.text.trim(),
      'photoUrl': photoUrl,
      'faceDetected': _croppedFaceImage != null,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Generate and store face embedding with better parameters
    if (_croppedFaceImage != null) {
      final success = await FaceRecognitionService.storeFaceEmbedding(
        docRef.id,
        _croppedFaceImage!,
        normalizationType: 'arcface',
      );
      
      if (success) {
        await _saveEmbeddingsToFirestore();
        print('Face embedding stored successfully for ${_nameController.text.trim()}');
      } else {
        print('Failed to store face embedding');
      }
    }

    await _loadPeople();

    if (mounted) {
      Navigator.pop(context);
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _croppedFaceImage != null
                ? 'Person added successfully with face recognition!'
                : 'Person added successfully (no face detected)',
          ),
          backgroundColor: _croppedFaceImage != null ? Colors.green : Colors.orange,
        ),
      );
    }
  } catch (e) {
    setState(() => _isUploading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding person: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


  void _resetForm() {
    setState(() {
      _selectedImage = null;
      _croppedFaceImage = null;
      _nameController.clear();
      _isUploading = false;
      _isDetectingFace = false;
      _recognitionResult = null;
      _recognitionMessage = null;
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('people')
          .doc(personId)
          .delete();

      if (photoUrl != null && photoUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(photoUrl).delete();
        } catch (storageError) {
          print('Storage deletion error: $storageError');
        }
      }
      // Remove face embedding
      FaceRecognitionService.removeFaceEmbedding(personId);
      await _saveEmbeddingsToFirestore();

      await _loadPeople();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$personName deleted successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Error deleting person: $e')));
      }
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
    bool? faceDetected;

    if (newImage != null) {
      final imageToUpload = _croppedFaceImage ?? newImage;
      faceDetected = _croppedFaceImage != null;

      // حذف الصورة القديمة
      if (oldPhotoUrl != null && oldPhotoUrl.isNotEmpty) {
        try {
          await FirebaseStorage.instance.refFromURL(oldPhotoUrl).delete();
        } catch (e) {
          print('Error deleting old image: $e');
        }
      }

      // رفع الصورة الجديدة
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('photos')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await storageRef.putFile(imageToUpload);
      photoUrl = await uploadTask.ref.getDownloadURL();

      // تحديث face embedding إذا كان هناك وجه جديد
      if (_croppedFaceImage != null) {
        // إزالة الـ embedding القديم أولاً
        FaceRecognitionService.removeFaceEmbedding(personId);
        
        // إضافة الـ embedding الجديد
        final success = await FaceRecognitionService.storeFaceEmbedding(
          personId,
          _croppedFaceImage!,
          normalizationType: 'arcface',
        );
        
        if (success) {
          await _saveEmbeddingsToFirestore();
          print('Face embedding updated for $newName');
        }
      } else {
        // إذا لم يتم اكتشاف وجه في الصورة الجديدة، احذف الـ embedding القديم
        FaceRecognitionService.removeFaceEmbedding(personId);
        await _saveEmbeddingsToFirestore();
      }
    }

    final updateData = <String, dynamic>{'name': newName.trim()};

    if (photoUrl != null) {
      updateData['photoUrl'] = photoUrl;
    }

    if (faceDetected != null) {
      updateData['faceDetected'] = faceDetected;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('people')
        .doc(personId)
        .update(updateData);

    await _loadPeople();

    if (mounted) {
      Navigator.pop(context);
      _resetForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            faceDetected == true
                ? 'Person updated successfully with face detection!'
                : faceDetected == false
                ? 'Person updated successfully (no face detected in new photo)'
                : 'Person updated successfully!',
          ),
          backgroundColor: faceDetected == true ? Colors.green : Colors.orange,
        ),
      );
    }
  } catch (e) {
    setState(() => _isUploading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating person: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

Future<void> _diagnoseFaceRecognition() async {
  try {
    final diagnosis = await FaceRecognitionService.diagnoseModel();
    print('=== Face Recognition Diagnosis ===');
    print(diagnosis);
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('System Diagnosis'),
          content: Text(diagnosis.toString()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  } catch (e) {
    print('Diagnosis error: $e');
  }
}

// إضافة دالة اختبار النظام
Future<void> _testRecognitionSystem() async {
  if (_people.isEmpty) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add some people first before testing'),
          backgroundColor: Colors.orange,
        ),
      );
    }
    return;
  }

  print('=== Testing Recognition System ===');
  print('Stored embeddings: ${FaceRecognitionService.getStoredEmbeddings().length}');
  print('People in database: ${_people.length}');
  
  final embeddings = FaceRecognitionService.getStoredEmbeddings();
  for (var entry in embeddings.entries) {
    print('${entry.key}: ${entry.value.length} dimensions');
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
            'Are you sure you want to delete "$personName"?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deletePerson(personId, personName, photoUrl);
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

  List<Map<String, dynamic>> get _filteredPeople {
    if (_searchQuery.isEmpty) return _people;
    return _people
        .where(
          (person) =>
              person['name'].toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

List<Map<String, dynamic>> get filteredPeople {
    if (_searchQuery.isEmpty) return _people;
    return _people
        .where((person) => 
            person['name'].toLowerCase().contains(_searchQuery.toLowerCase()))
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
                        
                        // Face Recognition Button
                        Container(
                          width: MediaQuery.of(context).size.width * 0.85,
                          height: 45,
                          margin: const EdgeInsets.only(bottom: 15),
                          child: ElevatedButton(
                          onPressed: _isRecognizing ? null : _showRecognitionSourceDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6B1D73),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                            ),
                            child: _isRecognizing
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.face_retouching_natural, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'Recognize Face',
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

                        // Recognition result message
                        if (_recognitionMessage != null) ...[
                          Container(
                            width: MediaQuery.of(context).size.width * 0.85,
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 15),
                            decoration: BoxDecoration(
                              color: _recognitionResult?.isMatch == true 
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: _recognitionResult?.isMatch == true 
                                    ? Colors.green 
                                    : Colors.orange,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              _recognitionMessage!,
                              style: TextStyle(
                                color: _recognitionResult?.isMatch == true 
                                    ? Colors.green[700] 
                                    : Colors.orange[700],
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],

                        // Search Bar
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
                  
                  // People List
                  _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(50.0),
                          child: CircularProgressIndicator(
                            color: Color(0xFFB14ABA),
                          ),
                        )
                      : _filteredPeople.isEmpty && _searchQuery.isNotEmpty
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
                                  "No people found matching your search",
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
                      : _people.isEmpty
                      ? Center(
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
                            children: _filteredPeople.map((person) {
                              final faceDetected = person['faceDetected'] ?? false;
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
                                      leading: Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundColor: Colors.white,
                                            backgroundImage: person['photoUrl'] != null
                                                ? NetworkImage(person['photoUrl'])
                                                : null,
                                            child: person['photoUrl'] == null
                                                ? const Icon(
                                                    Icons.person,
                                                    color: Colors.grey,
                                                  )
                                                : null,
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 0,
                                            child: Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: faceDetected
                                                    ? Colors.green
                                                    : Colors.orange,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Icon(
                                                faceDetected
                                                    ? Icons.face
                                                    : Icons.warning,
                                                color: Colors.white,
                                                size: 10,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      title: Text(
                                        person['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        faceDetected
                                            ? 'Face Detected & Trained'
                                            : 'No Face Detected',
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
                                              person['id'],
                                              person['name'] ?? 'Unknown',
                                              person['photoUrl'],
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
                                              person['id'],
                                              person['name'] ?? 'Unknown',
                                              person['photoUrl'],
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
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomePage()),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.home_outlined, size: 26, color: Color(0xFFB14ABA)),
                      SizedBox(height: 2),
                      Text(
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
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const RemindersPage()),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 26, color: Colors.black54),
                      SizedBox(height: 2),
                      Text('Reminders', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                const SizedBox(width: 55),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const SosScreen()),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.warning_amber_outlined, size: 26, color: Colors.black54),
                      SizedBox(height: 2),
                      Text('Emergency', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const SettingsPage()),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.settings, size: 26, color: Colors.black54),
                      SizedBox(height: 2),
                      Text('Settings', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 25,
            child: GestureDetector(
              onTap: () => _showAddDialog(),
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

  void showDeleteConfirmation(String personId, String personName, String? photoUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Delete Person',
            style: TextStyle(
              color: Color(0xFF6B1D73),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "$personName"? This will also remove their face recognition data.',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _deletePerson(personId, personName, photoUrl);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B1D73),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  const Text("Name", style: TextStyle(fontWeight: FontWeight.bold)),
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
                      if (_croppedFaceImage != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "Face Ready for Recognition",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else if (_selectedImage != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "No Face",
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
                    onTap: _isDetectingFace
                        ? null
                        : () async {
                            await _pickImage();
                            setDialogState(() {});
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
                          color: _croppedFaceImage != null
                              ? Colors.green
                              : _selectedImage != null
                              ? Colors.orange
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
                      child: _isDetectingFace
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(color: Color(0xFF6B1D73)),
                                SizedBox(height: 8),
                                Text(
                                  "Detecting face...",
                                  style: TextStyle(
                                    color: Color(0xFF6B1D73),
                                    fontWeight: FontWeight.w500,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            )
                          : _selectedImage == null
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.upload, size: 30, color: Color(0xFF6B1D73)),
                                SizedBox(height: 8),
                                Text(
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
                                    color: _croppedFaceImage != null
                                        ? Colors.green
                                        : Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    _croppedFaceImage != null
                                        ? "Face Detected & Ready"
                                        : "No Face Detected",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Tap to change photo",
                                  style: TextStyle(
                                    color: Color(0xFF6B1D73),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed: _isUploading ||
                              _nameController.text.trim().isEmpty ||
                              _selectedImage == null
                          ? null
                          : () async {
                              setDialogState(() => _isUploading = true);
                              await _addPerson();
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
                              "Add Person",
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

  void _showEditDialog(
    String personId,
    String currentName,
    String? currentPhotoUrl,
  ) {
    _resetForm();
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
                        "Current Photo",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (_croppedFaceImage != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "New Face Detected",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ] else if (_selectedImage != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            "No Face in New Photo",
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
                  Container(
                    width: double.infinity,
                    height: 80,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F4F9),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white,
                          backgroundImage: _selectedImage != null
                              ? FileImage(_selectedImage!)
                              : (currentPhotoUrl != null
                                    ? NetworkImage(currentPhotoUrl)
                                    : null),
                          child:
                              _selectedImage == null && currentPhotoUrl == null
                              ? const Icon(Icons.person, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _selectedImage != null
                                    ? "New photo selected"
                                    : "Current photo",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: _isDetectingFace
                                    ? null
                                    : () async {
                                        await _pickImage();
                                        setDialogState(() {});
                                      },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6B1D73),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _isDetectingFace
                                        ? "Detecting..."
                                        : "Change Photo",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 45,
                    child: ElevatedButton(
                      onPressed:
                          _isUploading || _nameController.text.trim().isEmpty
                          ? null
                          : () async {
                              setDialogState(() => _isUploading = true);
                              await _updatePerson(
                                personId,
                                _nameController.text.trim(),
                                _selectedImage,
                                currentPhotoUrl,
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
                              "Update Person",
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
