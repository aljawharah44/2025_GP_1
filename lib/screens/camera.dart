import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'dart:convert';
import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  final picker = ImagePicker();

  // Audio player
  final AudioPlayer _player = AudioPlayer();
  bool _busy = false;
  String _extractedText = "";

  // ADD: Store the selected image path
  String? _selectedImagePath;

  // IBM Watson TTS credentials (same as your Python code)
  static const String IBM_TTS_API_KEY =
      "U7NnAMm6pf5FhCnIIz6MVT8XoNB5C0bVKKmIhT3m5ijU";
  static const String IBM_TTS_URL =
      "https://api.us-south.text-to-speech.watson.cloud.ibm.com/instances/d6a38eaa-96bc-4b90-96c4-3eb7b3cc3654";

  // OCR service - Using the specific text recognition package
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    if (_cameras != null && _cameras!.isNotEmpty) {
      _controller = CameraController(
        _cameras![0],
        ResolutionPreset.max,
        enableAudio: false,
      );
      await _controller!.initialize();
      if (mounted) setState(() {});
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    final newIndex = _controller!.description == _cameras![0] ? 1 : 0;
    _controller = CameraController(
      _cameras![newIndex],
      ResolutionPreset.max,
      enableAudio: false,
    );
    await _controller!.initialize();
    if (mounted) setState(() {});
  }

  // OCR function - extract text from image (like pytesseract in your Python code)
  Future<String> _extractTextFromImage(String imagePath) async {
    try {
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      return recognizedText.text;
    } catch (e) {
      print('OCR Error: $e');
      return "";
    }
  }

  // TTS function - convert text to speech using IBM Watson (same as your Python code)
  Future<String?> _convertTextToSpeech(String text) async {
    try {
      // Prepare authentication (same as Python: base64 encode "apikey:API_KEY")
      final String auth = base64Encode(utf8.encode('apikey:$IBM_TTS_API_KEY'));

      final response = await http.post(
        Uri.parse('$IBM_TTS_URL/v1/synthesize'),
        headers: {
          'Authorization': 'Basic $auth',
          'Content-Type': 'application/json',
          'Accept': 'audio/mp3',
        },
        body: jsonEncode({
          'text': text,
          'voice': 'en-US_AllisonV3Voice', // Same voice as your Python code
          'accept': 'audio/mp3',
        }),
      );

      if (response.statusCode == 200) {
        // Save audio file to temporary directory
        final Directory tempDir = await getTemporaryDirectory();
        final String audioPath =
            '${tempDir.path}/output_${DateTime.now().millisecondsSinceEpoch}.mp3';
        final File audioFile = File(audioPath);
        await audioFile.writeAsBytes(response.bodyBytes);
        return audioPath;
      } else {
        print('TTS Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('TTS Exception: $e');
      return null;
    }
  }

  // Process image: OCR + TTS (combining your Python workflow)
  Future<void> _processImage(
    String imagePath, {
    bool fromGallery = false,
  }) async {
    setState(() => _busy = true);

    try {
      // MODIFIED: Store the image path if from gallery
      if (fromGallery) {
        _selectedImagePath = imagePath;
      }

      // Step 1: Extract text from image (like pytesseract.image_to_string in Python)
      String extractedText = await _extractTextFromImage(imagePath);

      setState(() {
        _extractedText = extractedText;
      });

      print("==== Extracted Text ====");
      print(extractedText);

      if (extractedText.trim().isNotEmpty) {
        // Step 2: Convert text to speech (like IBM TTS in Python)
        String? audioPath = await _convertTextToSpeech(extractedText);

        if (audioPath != null) {
          // Step 3: Play the audio (like playing output.mp3 in Python)
          await _player.stop();
          await _player.play(DeviceFileSource(audioPath));

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Text extracted and playing audio!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Text extracted but audio conversion failed, Try again',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No text detected in the image !'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _captureImage() async {
    if (_controller?.value.isInitialized != true) return;
    final file = await _controller!.takePicture();

    // MODIFIED: Clear selected image when capturing new photo
    setState(() {
      _selectedImagePath = null;
    });

    // Process the captured image
    await _processImage(file.path, fromGallery: false);
  }

  Future<void> _pickImage() async {
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    // MODIFIED: Mark as from gallery
    await _processImage(file.path, fromGallery: true);
  }

  // ADD: Function to return to camera mode
  void _returnToCamera() {
    setState(() {
      _selectedImagePath = null;
      _extractedText = "";
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    _player.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: _controller == null || !_controller!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // MODIFIED: Show selected image or camera preview
                Positioned.fill(
                  child: _selectedImagePath != null
                      ? Image.file(File(_selectedImagePath!), fit: BoxFit.cover)
                      : Transform.scale(
                          scale:
                              _controller!.value.aspectRatio /
                              (size.width / size.height),
                          child: Center(child: CameraPreview(_controller!)),
                        ),
                ),

                // Back button
                Positioned(
                  top: 40,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),

                // Feature info at top
                Positioned(
                  top: 40,
                  right: 16,
                  left: 80,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _selectedImagePath != null
                          ? 'Selected image - Text extracted and played'
                          : 'Take or upload a photo of text to hear it read aloud',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                // ADD: Return to camera button when image is selected
                if (_selectedImagePath != null)
                  Positioned(
                    top: 40,
                    right: 16,
                    child: GestureDetector(
                      onTap: _returnToCamera,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                    ),
                  ),

                // Extracted text display
                if (_extractedText.isNotEmpty)
                  Positioned(
                    top: 120,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Extracted Text:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _extractedText,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                            maxLines: 8,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Bottom controls
                Positioned(
                  bottom: 40,
                  left: 32,
                  right: 32,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Gallery picker
                        GestureDetector(
                          onTap: _busy ? null : _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.photo,
                              size: 28,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        // Capture button
                        GestureDetector(
                          onTap: _busy ? null : _captureImage,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4),
                              color: Colors.white.withOpacity(0.1),
                            ),
                            child: Center(
                              child: Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: _busy ? Colors.orange : Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: _busy
                                    ? Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        Icons.camera_alt,
                                        color: Colors.grey[800],
                                        size: 24,
                                      ),
                              ),
                            ),
                          ),
                        ),

                        // Camera switch (only show when in camera mode)
                        GestureDetector(
                          onTap: _busy || _selectedImagePath != null
                              ? null
                              : _switchCamera,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(
                                _selectedImagePath != null ? 0.1 : 0.2,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.cameraswitch,
                              size: 28,
                              color: _selectedImagePath != null
                                  ? Colors.white38
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Processing overlay
                if (_busy)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.25),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Processing image...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
