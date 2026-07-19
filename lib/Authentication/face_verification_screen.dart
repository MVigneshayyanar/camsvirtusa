import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Services/face_recognition_service.dart';
import '../Startup/routes.dart';

class FaceVerificationScreen extends StatefulWidget {
  final String studentId;

  const FaceVerificationScreen({super.key, required this.studentId});

  @override
  _FaceVerificationScreenState createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen> {
  CameraController? _cameraController;
  late FaceRecognitionService _faceService;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String _statusMessage = "Position your face in the camera for automatic verification.";
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _faceService = FaceRecognitionService();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = "No camera found.");
        return;
      }
      
      // Try to find the front camera
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _faceService.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        
        // Start auto-capture loop
        _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
          if (!_isProcessing && mounted) {
            _verifyFace();
          }
        });
      }
    } catch (e) {
      setState(() => _statusMessage = "Camera initialization failed.");
    }
  }

  Future<void> _verifyFace() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = "Processing...";
    });

    try {
      // Capture image
      final XFile imageFile = await _cameraController!.takePicture();
      File capturedFile = File(imageFile.path);

      // Extract embedding from live photo
      List<double>? liveEmbedding = await _faceService.extractEmbedding(capturedFile);

      if (liveEmbedding == null) {
        setState(() {
          _statusMessage = "No face detected in live photo. Try again.";
          _isProcessing = false;
        });
        return;
      }

      setState(() {
        _statusMessage = "Verifying with stored photo...";
      });

      // Extract embedding from stored asset photo
      String assetPath = 'assets/Students/${widget.studentId}.jpeg';
      List<double>? storedEmbedding = await _faceService.getEmbeddingFromAsset(assetPath);

      if (storedEmbedding == null) {
        setState(() {
          _statusMessage = "Could not find or process stored photo for ${widget.studentId}.";
          _isProcessing = false;
        });
        return;
      }

      // Compare
      double distance = _faceService.calculateDistance(liveEmbedding, storedEmbedding);
      print("🔍 FACE MATCH DISTANCE: \$distance (Needs to be < 0.85)");

      // Threshold lowered to 0.85 to be much stricter and prevent false positives
      if (distance < 0.85) {
        setState(() {
          _statusMessage = "Verification Successful!";
        });
        
        // Save login state
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', 'student');
        await prefs.setString('studentId', widget.studentId);
        
        // Store verification time
        final String verificationTime = DateTime.now().toIso8601String();
        await prefs.setString('lastVerificationTime', verificationTime);

        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          AppRoutes.studentDashboard,
          arguments: {
            'studentId': widget.studentId,
            'verificationTime': verificationTime,
          },
        );
      } else {
        setState(() {
          _statusMessage = "Verification Failed. Faces do not match.";
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = "An error occurred: \$e";
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Face Verification', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              "Hi ${widget.studentId}",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Center(
                child: _isCameraInitialized
                    ? Container(
                        width: 300,
                        height: 400,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFFF8C61), width: 3),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(17),
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: _isProcessing
                  ? const CircularProgressIndicator()
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
