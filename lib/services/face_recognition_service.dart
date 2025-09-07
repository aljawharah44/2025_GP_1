import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui';

class FaceRecognitionService {
  static Interpreter? _interpreter;
  static bool _isInitialized = false;
  static Map<String, List<double>> _storedEmbeddings = {};
  
  // تحسين إعدادات النموذج
  static const int INPUT_SIZE = 112;
  static const int EMBEDDING_SIZE = 512;
  
  // إعدادات التحسين
  static const double MIN_FACE_SIZE = 0.1; // تقليل الحد الأدنى
  static const double DEFAULT_THRESHOLD = 0.3; // تقليل العتبة الافتراضية
  
  static Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      print('Loading face recognition model...');
      
      final modelPaths = [
        'assets/models/arcface.tflite',
        'assets/models/facenet.tflite',
        'assets/models/mobilefacenet.tflite',
      ];
      
      for (String path in modelPaths) {
        try {
          _interpreter = await Interpreter.fromAsset(path);
          print('Successfully loaded model from: $path');
          
          // طباعة تفاصيل النموذج
          final inputDetails = _interpreter!.getInputTensor(0);
          final outputDetails = _interpreter!.getOutputTensor(0);
          print('Input shape: ${inputDetails.shape}, type: ${inputDetails.type}');
          print('Output shape: ${outputDetails.shape}, type: ${outputDetails.type}');
          
          _isInitialized = true;
          return true;
        } catch (e) {
          print('Failed to load $path: $e');
          continue;
        }
      }
      
      return false;
    } catch (e) {
      print('Initialization error: $e');
      return false;
    }
  }

  // معالجة صورة محسنة مع خيارات متعددة للتطبيع
  static Float32List preprocessImage(img.Image faceImage, {String normalizationType = 'arcface'}) {
    print('Preprocessing image: ${faceImage.width}x${faceImage.height}');
    
    // تحسين جودة الصورة
    var processedImage = img.adjustColor(faceImage, 
      contrast: 1.1,
      brightness: 1.02,
      saturation: 1.05,
    );
    
    // تحسين الحدة
    /*
    processedImage = img.convolution(processedImage, [
      -0.1, -0.1, -0.1,
      -0.1,  1.8, -0.1,
      -0.1, -0.1, -0.1
    ]);
    */
    // تغيير الحجم مع interpolation أفضل
    processedImage = img.copyResize(
      processedImage, 
      width: INPUT_SIZE, 
      height: INPUT_SIZE,
      interpolation: img.Interpolation.cubic
    );
    
    final input = Float32List(INPUT_SIZE * INPUT_SIZE * 3);
    int pixelIndex = 0;
    
    // أنواع التطبيع المختلفة
    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        final pixel = processedImage.getPixel(x, y);
        
        switch (normalizationType.toLowerCase()) {
          case 'arcface':
            // ArcFace normalization: [-1, 1]
            input[pixelIndex] = (pixel.r / 127.5) - 1.0;
            input[pixelIndex + 1] = (pixel.g / 127.5) - 1.0;
            input[pixelIndex + 2] = (pixel.b / 127.5) - 1.0;
            break;
          case 'facenet':
            // FaceNet normalization: [-1, 1] with different scaling
            input[pixelIndex] = (pixel.r - 127.5) / 128.0;
            input[pixelIndex + 1] = (pixel.g - 127.5) / 128.0;
            input[pixelIndex + 2] = (pixel.b - 127.5) / 128.0;
            break;
          case 'imagenet':
            // ImageNet normalization: [0, 1]
            input[pixelIndex] = pixel.r / 255.0;
            input[pixelIndex + 1] = pixel.g / 255.0;
            input[pixelIndex + 2] = pixel.b / 255.0;
            break;
          default:
            // Default: [-1, 1]
            input[pixelIndex] = (pixel.r / 127.5) - 1.0;
            input[pixelIndex + 1] = (pixel.g / 127.5) - 1.0;
            input[pixelIndex + 2] = (pixel.b / 127.5) - 1.0;
        }
        pixelIndex += 3;
      }
    }
    
    return input;
  }

  static Future<List<double>?> generateEmbedding(File imageFile, {String normalizationType = 'arcface'}) async {
    if (!_isInitialized) {
      final initialized = await initialize();
      if (!initialized) return null;
    }
    
    try {
      print('=== Generating embedding ===');
      
      if (!await imageFile.exists()) {
        print('Image file not found');
        return null;
      }
      
      // تحسين اكتشاف الوجه
      final faceRect = await detectFaceEnhanced(imageFile);
      if (faceRect == null) {
        print('No face detected');
        return null;
      }
      
      // قص الوجه مع padding أفضل
      final croppedFace = await cropFaceEnhanced(imageFile, faceRect);
      if (croppedFace == null) {
        print('Face cropping failed');
        return null;
      }
      
      print('Face processed: ${croppedFace.width}x${croppedFace.height}');
      
      // معالجة الصورة مع نوع التطبيع المحدد
      final input = preprocessImage(croppedFace, normalizationType: normalizationType);
      final inputTensor = input.reshape([1, INPUT_SIZE, INPUT_SIZE, 3]);
      
      // تحديد حجم الإخراج ديناميكياً
      final outputShape = _interpreter!.getOutputTensor(0).shape;
      final embeddingSize = outputShape.last;
      print('Expected embedding size: $embeddingSize');
      
      final outputTensor = List.generate(1, (i) => List.filled(embeddingSize, 0.0));
      
      // تشغيل النموذج مع قياس الوقت
      final stopwatch = Stopwatch()..start();
      _interpreter!.run(inputTensor, outputTensor);
      stopwatch.stop();
      
      print('Inference time: ${stopwatch.elapsedMilliseconds}ms');
      
      // تطبيع الـ embedding مع تحسينات
      final rawEmbedding = outputTensor[0].cast<double>();
      final normalizedEmbedding = _normalizeEmbeddingEnhanced(rawEmbedding);
      
      print('Embedding generated: ${normalizedEmbedding.length} dimensions');
      print('Embedding stats - Min: ${normalizedEmbedding.reduce(math.min).toStringAsFixed(3)}, Max: ${normalizedEmbedding.reduce(math.max).toStringAsFixed(3)}');
      
      return normalizedEmbedding;
      
    } catch (e, stackTrace) {
      print('Embedding generation error: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }

  // اكتشاف وجه محسن مع إعدادات أفضل
  static Future<Rect?> detectFaceEnhanced(File imageFile) async {
    final options = FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
      enableLandmarks: true, // مفيد للتأكد من جودة الوجه
      enableTracking: false,
      minFaceSize: MIN_FACE_SIZE, // تقليل الحد الأدنى
      performanceMode: FaceDetectorMode.accurate,
    );
    
    final faceDetector = FaceDetector(options: options);
    final inputImage = InputImage.fromFile(imageFile);
    final faces = await faceDetector.processImage(inputImage);
    faceDetector.close();
    
    if (faces.isNotEmpty) {
      print('Detected ${faces.length} faces');
      
      // تصفية الوجوه بناءً على الجودة
      Face? bestFace;
      double bestScore = 0;
      
      for (Face face in faces) {
        // حساب نقاط الجودة
        double qualityScore = _calculateFaceQuality(face);
        print('Face quality score: ${qualityScore.toStringAsFixed(2)}');
        
        if (qualityScore > bestScore) {
          bestScore = qualityScore;
          bestFace = face;
        }
      }
      
      if (bestFace != null) {
        print('Selected best face with score: ${bestScore.toStringAsFixed(2)}');
        return bestFace.boundingBox;
      }
    } else {
      print('No faces detected');
    }
    
    return null;
  }

  // حساب جودة الوجه
  static double _calculateFaceQuality(Face face) {
    double score = 0;
    
    // حجم الوجه (أكبر = أفضل)
    final faceArea = face.boundingBox.width * face.boundingBox.height;
    score += math.min(faceArea / 10000, 1.0) * 30;
    
    // زاوية الرأس (أقل = أفضل)
    if (face.headEulerAngleY != null) {
      score += (90 - face.headEulerAngleY!.abs()) / 90 * 25;
    }
    if (face.headEulerAngleZ != null) {
      score += (90 - face.headEulerAngleZ!.abs()) / 90 * 25;
    }
    
    // معالم الوجه (المزيد = أفضل)
    if (face.landmarks.isNotEmpty) {
      score += math.min(face.landmarks.length / 10, 1.0) * 20;
    }
    
    return score;
  }

  // قص وجه محسن مع padding ديناميكي
  static Future<img.Image?> cropFaceEnhanced(File imageFile, Rect faceRect) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return null;
      
      print('Original image: ${originalImage.width}x${originalImage.height}');
      print('Face rect: ${faceRect.left}, ${faceRect.top}, ${faceRect.width}, ${faceRect.height}');
      
      // حساب padding ديناميكي بناءً على حجم الوجه
      final faceSize = math.max(faceRect.width, faceRect.height);
      final paddingRatio = _calculateOptimalPadding(faceSize);
      final padding = (faceSize * paddingRatio).toInt();
      
      print('Calculated padding: $padding (ratio: ${paddingRatio.toStringAsFixed(2)})');
      
      // حساب منطقة القص مع التأكد من عدم تجاوز حدود الصورة
      final x = math.max(0, faceRect.left.toInt() - padding);
      final y = math.max(0, faceRect.top.toInt() - padding);
      final maxWidth = originalImage.width - x;
      final maxHeight = originalImage.height - y;
      final width = math.min(maxWidth, faceRect.width.toInt() + (padding * 2));
      final height = math.min(maxHeight, faceRect.height.toInt() + (padding * 2));
      
      if (width <= 0 || height <= 0) {
        print('Invalid crop dimensions');
        return null;
      }
      
      var croppedImage = img.copyCrop(originalImage, x: x, y: y, width: width, height: height);
      print('Cropped to: ${croppedImage.width}x${croppedImage.height}');
      
      // جعل الصورة مربعة
      final targetSize = math.max(croppedImage.width, croppedImage.height);
      final squareImage = img.Image(width: targetSize, height: targetSize);
      img.fill(squareImage, color: img.ColorRgb8(128, 128, 128)); // خلفية رمادية
      
      // وضع الوجه في المنتصف
      final offsetX = (targetSize - croppedImage.width) ~/ 2;
      final offsetY = (targetSize - croppedImage.height) ~/ 2;
      img.compositeImage(squareImage, croppedImage, dstX: offsetX, dstY: offsetY);
      
      print('Final square image: ${squareImage.width}x${squareImage.height}');
      return squareImage;
      
    } catch (e) {
      print('Enhanced face cropping error: $e');
      return null;
    }
  }

  // حساب padding مثالي بناءً على حجم الوجه
  static double _calculateOptimalPadding(double faceSize) {
    if (faceSize < 100) return 0.5; // وجه صغير - padding أكبر
    if (faceSize < 200) return 0.35;
    if (faceSize < 400) return 0.25;
    return 0.15; // وجه كبير - padding أصغر
  }

  // تطبيع محسن مع خيارات متعددة
  static List<double> _normalizeEmbeddingEnhanced(List<double> embedding) {
    // L2 normalization (الطريقة الأكثر شيوعاً)
    double norm = 0.0;
    for (double value in embedding) {
      norm += value * value;
    }
    norm = math.sqrt(norm);
    
    if (norm == 0.0 || norm.isNaN || norm.isInfinite) {
      print('Warning: Invalid norm value: $norm');
      return embedding;
    }
    
    final normalized = embedding.map((value) => value / norm).toList();
    
    // التحقق من صحة النتيجة
    double checkNorm = 0.0;
    for (double value in normalized) {
      if (value.isNaN || value.isInfinite) {
        print('Warning: Invalid normalized value detected');
        return embedding;
      }
      checkNorm += value * value;
    }
    
    print('Normalized embedding norm: ${math.sqrt(checkNorm).toStringAsFixed(6)}');
    return normalized;
  }

  // حساب تشابه محسن مع معايير متعددة
  static double calculateSimilarity(List<double> embedding1, List<double> embedding2) {
    if (embedding1.length != embedding2.length) {
      throw ArgumentError('Embedding length mismatch: ${embedding1.length} vs ${embedding2.length}');
    }
    
    // Cosine similarity (الأكثر دقة للـ face embeddings)
    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;
    
    for (int i = 0; i < embedding1.length; i++) {
      dotProduct += embedding1[i] * embedding2[i];
      norm1 += embedding1[i] * embedding1[i];
      norm2 += embedding2[i] * embedding2[i];
    }
    
    norm1 = math.sqrt(norm1);
    norm2 = math.sqrt(norm2);
    
    if (norm1 == 0.0 || norm2 == 0.0) return 0.0;
    
    final similarity = dotProduct / (norm1 * norm2);
    return math.max(0.0, math.min(1.0, similarity)); // تقييد القيمة بين 0 و 1
  }

  // التعرف على الوجه مع خيارات متقدمة
  static Future<RecognitionResult?> recognizeFace(
    File imageFile, {
    double threshold = DEFAULT_THRESHOLD,
    String normalizationType = 'arcface',
    bool useAdaptiveThreshold = true,
  }) async {
    print('=== Enhanced Face Recognition ===');
    print('Using threshold: $threshold, normalization: $normalizationType');
    
    final queryEmbedding = await generateEmbedding(imageFile, normalizationType: normalizationType);
    if (queryEmbedding == null) {
      print('Failed to generate query embedding');
      return null;
    }
    
    if (_storedEmbeddings.isEmpty) {
      print('No stored embeddings available');
      return RecognitionResult(personId: 'unknown', similarity: 0.0, isMatch: false);
    }
    
    String? bestMatchId;
    double highestSimilarity = -1.0;
    List<double> allSimilarities = [];
    
    print('Comparing with ${_storedEmbeddings.length} stored faces...');
    for (var entry in _storedEmbeddings.entries) {
      try {
        final similarity = calculateSimilarity(queryEmbedding, entry.value);
        allSimilarities.add(similarity);
        print('${entry.key}: ${(similarity * 100).toStringAsFixed(1)}%');
        
        if (similarity > highestSimilarity) {
          highestSimilarity = similarity;
          bestMatchId = entry.key;
        }
      } catch (e) {
        print('Error comparing with ${entry.key}: $e');
      }
    }
    
    // Adaptive threshold based on similarity distribution
    double finalThreshold = threshold;
    if (useAdaptiveThreshold && allSimilarities.isNotEmpty) {
      allSimilarities.sort((a, b) => b.compareTo(a));
      final secondHighest = allSimilarities.length > 1 ? allSimilarities[1] : 0.0;
      final gap = highestSimilarity - secondHighest;
      
      // إذا كان هناك فجوة كبيرة، قلل العتبة
      if (gap > 0.2) {
        finalThreshold = math.min(threshold, highestSimilarity - 0.05);
        print('Adaptive threshold applied: ${finalThreshold.toStringAsFixed(3)}');
      }
    }
    
    final isMatch = highestSimilarity >= finalThreshold;
    print('Best match: $bestMatchId (${(highestSimilarity * 100).toStringAsFixed(1)}%) - Match: $isMatch (threshold: ${(finalThreshold * 100).toStringAsFixed(1)}%)');
    
    return RecognitionResult(
      personId: bestMatchId ?? 'unknown',
      similarity: highestSimilarity,
      isMatch: isMatch,
      threshold: finalThreshold,
    );
  }

  // باقي الدوال مع تحسينات
  static Future<bool> storeFaceEmbedding(String personId, File imageFile, {String normalizationType = 'arcface'}) async {
    final embedding = await generateEmbedding(imageFile, normalizationType: normalizationType);
    if (embedding != null && embedding.isNotEmpty) {
      _storedEmbeddings[personId] = embedding;
      print('Stored embedding for $personId (${embedding.length} dims, norm: ${_calculateEmbeddingNorm(embedding).toStringAsFixed(3)})');
      return true;
    }
    print('Failed to store embedding for $personId');
    return false;
  }

  static double _calculateEmbeddingNorm(List<double> embedding) {
    double norm = 0.0;
    for (double value in embedding) {
      norm += value * value;
    }
    return math.sqrt(norm);
  }

  // Getters and utilities
  static Map<String, List<double>> getStoredEmbeddings() => Map.from(_storedEmbeddings);
  static void loadEmbeddings(Map<String, List<double>> embeddings) {
    _storedEmbeddings = Map.from(embeddings);
    print('Loaded ${_storedEmbeddings.length} embeddings');
  }
  static void clearStoredEmbeddings() {
    _storedEmbeddings.clear();
    print('Cleared all stored embeddings');
  }
  static void removeFaceEmbedding(String personId) {
    final removed = _storedEmbeddings.remove(personId);
    print('Removed embedding for $personId: ${removed != null}');
  }
  
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
    print('Face recognition service disposed');
  }

  // وظائف تشخيص إضافية
  static Future<Map<String, dynamic>> diagnoseModel() async {
    if (!_isInitialized) await initialize();
    
    return {
      'initialized': _isInitialized,
      'interpreter_available': _interpreter != null,
      'stored_embeddings_count': _storedEmbeddings.length,
      'input_shape': _interpreter?.getInputTensor(0).shape,
      'output_shape': _interpreter?.getOutputTensor(0).shape,
    };
  }
}

class RecognitionResult {
  final String personId;
  final double similarity;
  final bool isMatch;
  final double threshold;
  
  RecognitionResult({
    required this.personId,
    required this.similarity,
    required this.isMatch,
    this.threshold = 0.3,
  });
  
  @override
  String toString() {
    return 'RecognitionResult(personId: $personId, similarity: ${(similarity * 100).toStringAsFixed(1)}%, isMatch: $isMatch, threshold: ${(threshold * 100).toStringAsFixed(1)}%)';
  }
}