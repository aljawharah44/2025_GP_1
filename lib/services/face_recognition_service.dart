import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  static final FaceRecognitionService _instance = FaceRecognitionService._internal();
  factory FaceRecognitionService() => _instance;
  FaceRecognitionService._internal();

  Interpreter? _interpreter;
  bool _isModelLoaded = false;

  // Model input/output dimensions
  static const int inputSize = 160;
  static const int embeddingSize = 512;

  Future<bool> loadModel() async {
    try {
      if (_isModelLoaded) return true;

      // Load the FaceNet model
      _interpreter = await Interpreter.fromAsset('models/facenet.tflite');
      _isModelLoaded = true;
      print('✅ FaceNet model loaded successfully');
      return true;
    } catch (e) {
      print('❌ Error loading FaceNet model: $e');
      return false;
    }
  }

  void dispose() {
    _interpreter?.close();
    _isModelLoaded = false;
  }

  // Generate face embedding from image file
  Future<List<double>?> generateEmbedding(File imageFile) async {
    if (!_isModelLoaded || _interpreter == null) {
      print('❌ Model not loaded');
      return null;
    }

    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final input = _preprocessImage(image);

      final output = List.generate(1, (_) => List.filled(embeddingSize, 0.0));
      _interpreter!.run(input, output);

      final embedding = _normalizeEmbedding(output[0].cast<double>());
      return embedding;
    } catch (e) {
      print('❌ Error generating embedding: $e');
      return null;
    }
  }

  // Generate face embedding from image bytes (camera)
  Future<List<double>?> generateEmbeddingFromBytes(Uint8List imageBytes) async {
    if (!_isModelLoaded || _interpreter == null) {
      print('❌ Model not loaded');
      return null;
    }

    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      final input = _preprocessImage(image);

      final output = List.generate(1, (_) => List.filled(embeddingSize, 0.0));
      _interpreter!.run(input, output);

      final embedding = _normalizeEmbedding(output[0].cast<double>());
      return embedding;
    } catch (e) {
      print('❌ Error generating embedding from bytes: $e');
      return null;
    }
  }

  // Preprocess image for FaceNet model
  List _preprocessImage(img.Image image) {
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    final input = Float32List(1 * inputSize * inputSize * 3);
    int pixelIndex = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);

        // Pixel in image >= 4.0.0 is an object with r,g,b,a
        final r = (pixel.r.toDouble() / 127.5) - 1.0;
        final g = (pixel.g.toDouble() / 127.5) - 1.0;
        final b = (pixel.b.toDouble() / 127.5) - 1.0;

        input[pixelIndex++] = r;
        input[pixelIndex++] = g;
        input[pixelIndex++] = b;
      }
    }

    return input.reshape([1, inputSize, inputSize, 3]);
  }

  // Normalize embedding (L2)
  List<double> _normalizeEmbedding(List<double> embedding) {
    double sum = 0.0;
    for (double v in embedding) {
      sum += v * v;
    }
    final norm = sqrt(sum);
    if (norm == 0) return embedding;
    return embedding.map((v) => v / norm).toList();
  }

  // Cosine similarity
  double calculateSimilarity(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 0.0;

    double dot = 0.0, norm1 = 0.0, norm2 = 0.0;
    for (int i = 0; i < e1.length; i++) {
      dot += e1[i] * e2[i];
      norm1 += e1[i] * e1[i];
      norm2 += e2[i] * e2[i];
    }
    if (norm1 == 0 || norm2 == 0) return 0.0;
    return dot / (sqrt(norm1) * sqrt(norm2));
  }

  // Find best match
  Map<String, dynamic>? findBestMatch(
    List<double> queryEmbedding,
    List<Map<String, dynamic>>
storedPeople, {
    double threshold = 0.6,
  }) {
    double bestSim = 0.0;
    Map<String, dynamic>? bestMatch;

    for (final person in storedPeople) {
      final storedEmbedding = person['embedding'];
      if (storedEmbedding == null) continue;

      List<double> embedding;
      if (storedEmbedding is String) {
        embedding = storedEmbedding.split(',').map((e) => double.tryParse(e) ?? 0.0).toList();
      } else if (storedEmbedding is List) {
        embedding = storedEmbedding.cast<double>();
      } else {
        continue;
      }

      final sim = calculateSimilarity(queryEmbedding, embedding);
      if (sim > bestSim && sim >= threshold) {
        bestSim = sim;
        bestMatch = {...person, 'similarity': sim};
      }
    }
    return bestMatch;
  }
}

// Extension to add reshape for Float32List
extension ReshapeExt on Float32List {
  List reshape(List<int> dims) {
    if (dims.length != 4) {
      throw ArgumentError('Only 4D reshape is supported');
    }
    int batch = dims[0], height = dims[1], width = dims[2], channels = dims[3];
    if (length != batch * height * width * channels) {
      throw ArgumentError('Invalid dimensions for reshape');
    }

    var reshaped = List.generate(
      batch,
      (_) => List.generate(
        height,
        (_) => List.generate(
          width,
          (_) => List.filled(channels, 0.0),
        ),
      ),
    );

    int index = 0;
    for (int b = 0; b < batch; b++) {
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          for (int c = 0; c < channels; c++) {
            reshaped[b][y][x][c] = this[index++];
          }
        }
      }
    }
    return reshaped;
  }
}

// Helper sqrt
double sqrt(double x) {
  if (x < 0) return double.nan;
  if (x == 0) return 0;
  double guess = x, last = 0;
  while ((guess - last).abs() > 0.000001) {
    last = guess;
    guess = (guess + x / guess) / 2;
  }
  return guess;
}