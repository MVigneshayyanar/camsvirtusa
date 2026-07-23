import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  late Interpreter _interpreter;
  late FaceDetector _faceDetector;
  bool _isInitialized = false;
  
  // MobileFaceNet typically uses 112x112 input
  static const int _inputSize = 112; 

  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // 1. Initialize TFLite model
    try {
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');
    } catch (e) {
      print('Error loading model: $e');
      rethrow;
    }
    
    // 2. Initialize ML Kit Face Detector
    final options = FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);
    
    _isInitialized = true;
  }

  /// Extracts a 192-dimensional embedding from the given image file.
  Future<List<double>?> extractEmbedding(File imageFile) async {
    if (!_isInitialized) await initialize();

    // 1. Detect face
    final inputImage = InputImage.fromFilePath(imageFile.path);
    final faces = await _faceDetector.processImage(inputImage);
    
    if (faces.isEmpty) {
      print("No face detected in image.");
      return null;
    }
    
    // Use the largest face detected
    Face largestFace = faces.reduce((curr, next) => 
      (curr.boundingBox.width * curr.boundingBox.height) > 
      (next.boundingBox.width * next.boundingBox.height) ? curr : next
    );

    // 2. Crop face from image
    final bytes = await imageFile.readAsBytes();
    img.Image? originalImage = img.decodeImage(bytes);
    if (originalImage == null) return null;

    final boundingBox = largestFace.boundingBox;
    
    int x = max(0, boundingBox.left.toInt());
    int y = max(0, boundingBox.top.toInt());
    int w = min(originalImage.width - x, boundingBox.width.toInt());
    int h = min(originalImage.height - y, boundingBox.height.toInt());
    
    img.Image croppedImage = img.copyCrop(originalImage, x: x, y: y, width: w, height: h);

    // 3. Resize and preprocess for MobileFaceNet
    img.Image resizedImage = img.copyResizeCropSquare(croppedImage, size: _inputSize);

    // Preprocess: convert to Float32 array, normalize between -1 and 1
    var input = List.generate(1, (i) => List.generate(_inputSize, (y) => List.generate(_inputSize, (x) => List.generate(3, (c) => 0.0))));
    
    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        // MobileFaceNet uses range [-1, 1] usually. (value - 127.5) / 128.0
        input[0][y][x][0] = (pixel.r - 127.5) / 128.0; // Red
        input[0][y][x][1] = (pixel.g - 127.5) / 128.0; // Green
        input[0][y][x][2] = (pixel.b - 127.5) / 128.0; // Blue
      }
    }

    // 4. Run inference
    var output = List.generate(1, (i) => List.filled(192, 0.0));
    _interpreter.run(input, output);

    // 5. Normalize embedding (L2 norm)
    List<double> embedding = output[0];
    double sum = 0.0;
    for (double e in embedding) {
      sum += e * e;
    }
    double norm = sqrt(sum);
    for (int i = 0; i < embedding.length; i++) {
      embedding[i] /= norm;
    }

    return embedding;
  }

  /// Calculates Euclidean distance between two embeddings.
  double calculateDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 999.0;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      double diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  /// Get embedding from an asset file (e.g. assets/Students/SEC23CJ007.jpeg)
  Future<List<double>?> getEmbeddingFromAsset(String assetPath) async {
    try {
      final byteData = await rootBundle.load(assetPath);
      final tempDir = await getTemporaryDirectory();
      // Ensure unique filename per student to prevent any caching/overlap issues
      final uniqueName = assetPath.split('/').last;
      final tempFile = File('${tempDir.path}/temp_\$uniqueName');
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes), flush: true);
      
      return await extractEmbedding(tempFile);
    } catch (e) {
      print('Error getting embedding from asset: $e');
      return null;
    }
  }

  void dispose() {
    _interpreter.close();
    _faceDetector.close();
    _isInitialized = false;
  }
}
