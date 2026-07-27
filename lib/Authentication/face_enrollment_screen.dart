import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../Services/face_recognition_service.dart';
import '../Startup/routes.dart';

/// Guides the student through 4 face captures to build a robust embedding set.
/// Shown only once on the very first login (when no face data exists).
class FaceEnrollmentScreen extends StatefulWidget {
  final String studentId;
  const FaceEnrollmentScreen({super.key, required this.studentId});

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen>
    with SingleTickerProviderStateMixin {
  // ── App theme colors ────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFFFF8C61);
  static const Color _success = Color(0xFF4CAF82);
  static const Color _bgColor = Colors.white;

  // ── camera ──────────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // ── service ──────────────────────────────────────────────────────────────────
  final FaceRecognitionService _faceService = FaceRecognitionService();

  // ── state ───────────────────────────────────────────────────────────────────
  int _currentStep = 0; // 0..3 = the 4 capture steps, 5 = done
  bool _isCapturing = false;
  bool _isSaving = false;
  String _statusMessage = '';
  final List<List<double>> _collectedEmbeddings = [];

  // ── animation ────────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ── step metadata ────────────────────────────────────────────────────────────
  static const List<Map<String, dynamic>> _steps = [
    {
      'instruction': 'Look straight at\nthe camera — neutral',
      'icon': Icons.face,
    },
    {
      'instruction': 'Look straight at\nthe camera — slight smile',
      'icon': Icons.sentiment_satisfied,
    },
    {
      'instruction': 'Look straight at\nthe camera — move closer',
      'icon': Icons.zoom_in,
    },
    {
      'instruction': 'Look straight at\nthe camera — natural expression',
      'icon': Icons.face_retouching_natural,
    },
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim =
        Tween<double>(begin: 1.0, end: 1.06).animate(_pulseController);

    _statusMessage = _steps[0]['instruction'] as String;
    _initCamera();
  }

  // ── Camera ──────────────────────────────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _statusMessage = 'No camera found.');
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController =
          CameraController(front, ResolutionPreset.high, enableAudio: false);
      await _cameraController!.initialize();
      await _faceService.initialize();
      if (mounted) setState(() => _isCameraReady = true);
    } catch (e) {
      if (mounted) setState(() => _statusMessage = 'Camera error: $e');
    }
  }

  // ── Capture a single step ───────────────────────────────────────────────────

  Future<void> _captureStep() async {
    if (_isCapturing ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized) {
      return;
    }

    setState(() {
      _isCapturing = true;
      _statusMessage = 'Capturing…';
    });

    try {
      final XFile xFile = await _cameraController!.takePicture();
      final File imageFile = File(xFile.path);

      setState(() => _statusMessage = 'Analysing face…');
      final embedding = await _faceService.extractEmbedding(imageFile);

      if (embedding == null) {
        setState(() {
          _statusMessage =
              'No face detected.\n${_steps[_currentStep]['instruction']}';
          _isCapturing = false;
        });
        return;
      }

      // ── Cross-person validation ─────────────────────────────────────────────
      // Since all 4 steps are frontal, same person's expressions produce
      // distance 0.20–0.50. A different person's frontal face produces 0.65+.
      // Since all 4 steps are frontal, same person's expressions produce
      // distance 0.20–0.65. A different person's frontal face produces 0.85+.
      // Threshold 0.75 safely blocks a different student from enrolling steps.
      if (_collectedEmbeddings.isNotEmpty) {
        final distance = _faceService.calculateDistance(
            embedding, _collectedEmbeddings[0]);
        debugPrint('[Enrollment] Cross-step distance: $distance');
        if (distance > 0.75) {
          setState(() {
            _statusMessage =
                'Different face detected!\nOnly one person should complete all 4 steps.\n\n${_steps[_currentStep]['instruction']}';
            _isCapturing = false;
          });
          return;
        }
      }

      _collectedEmbeddings.add(embedding);

      if (_currentStep < _steps.length - 1) {
        setState(() {
          _currentStep++;
          _isCapturing = false;
          _statusMessage = _steps[_currentStep]['instruction'] as String;
        });
      } else {
        await _saveEnrollment();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e\nTry again.';
        _isCapturing = false;
      });
    }
  }

  // ── Save to Firebase + local ────────────────────────────────────────────────

  Future<void> _saveEnrollment() async {
    setState(() {
      _isSaving = true;
      _statusMessage = 'Saving your face data…';
    });

    try {
      await _faceService.saveEmbeddingsToFirebase(
          widget.studentId, _collectedEmbeddings);
      await _faceService.saveEmbeddingsLocally(
          widget.studentId, _collectedEmbeddings);

      setState(() {
        _currentStep = 5; // done state
        _isSaving = false;
      });

      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final verificationTime = DateTime.now().toIso8601String();
      Navigator.pushReplacementNamed(
        context,
        AppRoutes.studentDashboard,
        arguments: {
          'studentId': widget.studentId,
          'verificationTime': verificationTime,
        },
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
        _statusMessage = 'Failed to save: $e\nPlease try again.';
        _currentStep = 3;
      });
    }
  }

  // ── Dispose ──────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _pulseController.dispose();
    _cameraController?.dispose();
    _faceService.dispose();
    super.dispose();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        automaticallyImplyLeading: false,
        title: Text(
          'Face Enrollment',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: SafeArea(
        child: _currentStep == 5 ? _buildSuccessView() : _buildEnrollmentView(),
      ),
    );
  }

  // ── Success View ─────────────────────────────────────────────────────────────

  Widget _buildSuccessView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _success.withValues(alpha: 0.1),
              border: Border.all(color: _success, width: 3),
            ),
            child: Icon(Icons.check_rounded, color: _success, size: 60),
          ),
          const SizedBox(height: 28),
          Text(
            'Face Enrolled!',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Colors.black,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '4 face samples saved successfully.\nTaking you to the dashboard…',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  // ── Enrollment View ──────────────────────────────────────────────────────────

  Widget _buildEnrollmentView() {
    return Column(
      children: [
        // ── Sub-header ──
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            children: [
              Text(
                'Hi ${widget.studentId}  •  First-time setup',
                style: TextStyle(fontSize: 13, color: Colors.black45),
              ),
              const SizedBox(height: 16),
              // Progress row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _steps.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: i == _currentStep ? 28 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: i < _currentStep
                          ? _success
                          : i == _currentStep
                              ? _primary
                              : const Color(0xFFE5E5E5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Step ${_currentStep + 1} of ${_steps.length}',
                style: TextStyle(fontSize: 12, color: Colors.black38),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Camera Preview ──
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: _isCameraReady
                ? ScaleTransition(
                    scale: _pulseAnim,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: _primary, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: _primary.withValues(alpha: 0.18),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(25),
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                : Center(
                    child: CircularProgressIndicator(color: _primary),
                  ),
          ),
        ),

        const SizedBox(height: 20),

        // ── Instruction ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            children: [
              Icon(
                _steps[_currentStep < _steps.length
                    ? _currentStep
                    : _steps.length - 1]['icon'] as IconData,
                color: _primary,
                size: 30,
              ),
              const SizedBox(height: 8),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Capture Button ──
        Padding(
          padding: const EdgeInsets.fromLTRB(30, 0, 30, 36),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed:
                  (_isCapturing || _isSaving || !_isCameraReady)
                      ? null
                      : _captureStep,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                disabledBackgroundColor: _primary.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: (_isCapturing || _isSaving)
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          _currentStep < _steps.length - 1
                              ? 'Capture & Next'
                              : 'Capture & Finish',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
