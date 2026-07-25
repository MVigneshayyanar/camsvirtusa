import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  late Interpreter _interpreter;
  late FaceDetector _faceDetector;
  bool _isInitialized = false;

  // MobileFaceNet input size
  static const int _inputSize = 112;

  // Firestore key under each student doc where embeddings are stored
  static const String _firebaseEmbeddingsKey = 'faceEmbeddings';

  // SharedPreferences key prefix for local cache
  static const String _localEmbeddingsPrefixKey = 'face_embeddings_';

  // Verification threshold — minimum Euclidean distance to accept as same person.
  // With multiple reference embeddings this can be kept strict.
  static const double verificationThreshold = 0.85;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite');
    } catch (e) {
      debugPrint('[FaceService] Error loading TFLite model: $e');
      rethrow;
    }

    final options = FaceDetectorOptions(
      enableContours: false,
      enableLandmarks: false,
      enableClassification: false,
      performanceMode: FaceDetectorMode.accurate,
    );
    _faceDetector = FaceDetector(options: options);

    _isInitialized = true;
  }

  // ---------------------------------------------------------------------------
  // Core: Extract Embedding from a File
  // ---------------------------------------------------------------------------

  /// Detects the largest face in [imageFile], crops it, runs MobileFaceNet,
  /// and returns a normalised 192-d embedding, or null if no face is found.
  Future<List<double>?> extractEmbedding(File imageFile) async {
    if (!_isInitialized) await initialize();

    final inputImage = InputImage.fromFilePath(imageFile.path);
    final faces = await _faceDetector.processImage(inputImage);

    if (faces.isEmpty) {
      debugPrint('[FaceService] No face detected.');
      return null;
    }

    // Use the largest face
    final face = faces.reduce((curr, next) =>
        (curr.boundingBox.width * curr.boundingBox.height) >
                (next.boundingBox.width * next.boundingBox.height)
            ? curr
            : next);

    final bytes = await imageFile.readAsBytes();
    final img.Image? original = img.decodeImage(bytes);
    if (original == null) return null;

    final box = face.boundingBox;
    final int x = max(0, box.left.toInt());
    final int y = max(0, box.top.toInt());
    final int w = min(original.width - x, box.width.toInt());
    final int h = min(original.height - y, box.height.toInt());

    final img.Image cropped =
        img.copyCrop(original, x: x, y: y, width: w, height: h);
    final img.Image resized =
        img.copyResizeCropSquare(cropped, size: _inputSize);

    // Build input tensor [1, 112, 112, 3] normalised to [-1, 1]
    var input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (py) => List.generate(
          _inputSize,
          (px) => List.generate(3, (_) => 0.0),
        ),
      ),
    );

    for (int py = 0; py < _inputSize; py++) {
      for (int px = 0; px < _inputSize; px++) {
        final pixel = resized.getPixel(px, py);
        input[0][py][px][0] = (pixel.r - 127.5) / 128.0;
        input[0][py][px][1] = (pixel.g - 127.5) / 128.0;
        input[0][py][px][2] = (pixel.b - 127.5) / 128.0;
      }
    }

    var output = List.generate(1, (_) => List.filled(192, 0.0));
    _interpreter.run(input, output);

    // L2-normalise the embedding
    List<double> embedding = List<double>.from(output[0]);
    double norm = sqrt(embedding.fold(0.0, (acc, e) => acc + e * e));
    if (norm > 0) {
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= norm;
      }
    }

    return embedding;
  }

  // ---------------------------------------------------------------------------
  // Distance Calculation
  // ---------------------------------------------------------------------------

  /// Euclidean distance between two embeddings.
  double calculateDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 999.0;
    double sum = 0.0;
    for (int i = 0; i < e1.length; i++) {
      final diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  /// Returns the **minimum** distance between [liveEmbedding] and any of the
  /// [storedEmbeddings]. A lower value means a better match.
  double calculateBestDistance(
      List<double> liveEmbedding, List<List<double>> storedEmbeddings) {
    double best = 999.0;
    for (final stored in storedEmbeddings) {
      final d = calculateDistance(liveEmbedding, stored);
      if (d < best) best = d;
    }
    return best;
  }

  // ---------------------------------------------------------------------------
  // Enrollment Detection
  // ---------------------------------------------------------------------------

  /// Returns true if the student already has face embeddings stored locally
  /// or in Firebase.
  Future<bool> hasEnrolledFace(String studentId) async {
    // Check local cache first (fast)
    final local = await loadEmbeddingsLocally(studentId);
    if (local != null && local.isNotEmpty) return true;

    // Fallback: check Firebase
    final remote = await loadEmbeddingsFromFirebase(studentId);
    if (remote != null && remote.isNotEmpty) {
      // Cache locally for future use
      await saveEmbeddingsLocally(studentId, remote);
      return true;
    }

    return false;
  }

  // ---------------------------------------------------------------------------
  // Firebase Storage
  // ---------------------------------------------------------------------------

  /// Saves [embeddings] (a list of 192-d vectors) to the student's Firestore
  /// document under [_firebaseEmbeddingsKey].
  Future<void> saveEmbeddingsToFirebase(
      String studentId, List<List<double>> embeddings) async {
    try {
      // Encode as List<List<double>> — Firestore supports nested arrays via
      // storing as a JSON string to avoid type issues.
      final encoded = json.encode(embeddings);
      await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(studentId)
          .update({_firebaseEmbeddingsKey: encoded});
      debugPrint('[FaceService] Embeddings saved to Firebase for $studentId');
    } catch (e) {
      debugPrint('[FaceService] Firebase save error: $e');
      rethrow;
    }
  }

  /// Loads embeddings from Firebase for [studentId].
  /// Returns null if not found or on error.
  Future<List<List<double>>?> loadEmbeddingsFromFirebase(
      String studentId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(studentId)
          .get();

      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null || !data.containsKey(_firebaseEmbeddingsKey)) {
        return null;
      }

      final encoded = data[_firebaseEmbeddingsKey] as String?;
      if (encoded == null || encoded.isEmpty) return null;

      final decoded = json.decode(encoded) as List<dynamic>;
      return decoded
          .map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList();
    } catch (e) {
      debugPrint('[FaceService] Firebase load error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Local Cache (SharedPreferences)
  // ---------------------------------------------------------------------------

  /// Persists [embeddings] in SharedPreferences so verification is fast and
  /// works without an internet connection.
  Future<void> saveEmbeddingsLocally(
      String studentId, List<List<double>> embeddings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = json.encode(embeddings);
      await prefs.setString('$_localEmbeddingsPrefixKey$studentId', encoded);
      debugPrint('[FaceService] Embeddings cached locally for $studentId');
    } catch (e) {
      debugPrint('[FaceService] Local save error: $e');
    }
  }

  /// Loads locally cached embeddings for [studentId]. Returns null if none.
  Future<List<List<double>>?> loadEmbeddingsLocally(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded =
          prefs.getString('$_localEmbeddingsPrefixKey$studentId');
      if (encoded == null || encoded.isEmpty) return null;

      final decoded = json.decode(encoded) as List<dynamic>;
      return decoded
          .map((e) => (e as List<dynamic>).map((v) => (v as num).toDouble()).toList())
          .toList();
    } catch (e) {
      debugPrint('[FaceService] Local load error: $e');
      return null;
    }
  }

  /// Loads embeddings: tries local cache first, falls back to Firebase,
  /// and caches the result locally if fetched from Firebase.
  Future<List<List<double>>?> loadEmbeddings(String studentId) async {
    var embeddings = await loadEmbeddingsLocally(studentId);
    if (embeddings != null && embeddings.isNotEmpty) return embeddings;

    embeddings = await loadEmbeddingsFromFirebase(studentId);
    if (embeddings != null && embeddings.isNotEmpty) {
      await saveEmbeddingsLocally(studentId, embeddings);
    }
    return embeddings;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  void dispose() {
    if (_isInitialized) {
      _interpreter.close();
      _faceDetector.close();
      _isInitialized = false;
    }
  }
}
