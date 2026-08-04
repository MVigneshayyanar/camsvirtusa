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
  State<FaceVerificationScreen> createState() => _FaceVerificationScreenState();
}

class _FaceVerificationScreenState extends State<FaceVerificationScreen>
    with SingleTickerProviderStateMixin {
  // ── App theme colors ────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFFFF8C61);
  static const Color _success = Color(0xFF4CAF82);
  static const Color _failure = Color(0xFFE57373);
  static const Color _bgColor = Colors.white;

  // ── camera ──────────────────────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _isCameraReady = false;

  // ── service ──────────────────────────────────────────────────────────────────
  final FaceRecognitionService _faceService = FaceRecognitionService();
  List<List<double>>? _storedEmbeddings;

  // ── state ───────────────────────────────────────────────────────────────────
  bool _isProcessing = false;
  bool _verificationDone = false;
  bool _verificationSuccess = false;
  String _statusMessage = '';
  double? _lastDistance;
  int _attemptCount = 0;

  // ── animation ────────────────────────────────────────────────────────────────
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // ── auto-verify timer ────────────────────────────────────────────────────────
  Timer? _autoTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(_pulseController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }
    });

    _init();
  }

  Future<void> _init() async {
    await _initCamera();
    await _loadEmbeddings();
    _startAutoVerify();
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

  // ── Load stored embeddings ─────────────────────────────────────────────────

  Future<void> _loadEmbeddings() async {
    setState(() => _statusMessage = 'Loading face data…');
    _storedEmbeddings = await _faceService.loadEmbeddings(widget.studentId);

    if (_storedEmbeddings == null || _storedEmbeddings!.isEmpty) {
      if (mounted) {
        setState(
            () => _statusMessage = 'No face data found. Please enrol first.');
      }
    } else {
      if (mounted) {
        setState(() => _statusMessage = 'Position your face in the frame.');
      }
    }
  }

  // ── Auto-verify loop ──────────────────────────────────────────────────────

  void _startAutoVerify() {
    _autoTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!_isProcessing && !_verificationDone && mounted) {
        _verify();
      }
    });
  }

  // ── Verify ────────────────────────────────────────────────────────────────

  Future<void> _verify() async {
    if (_cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _storedEmbeddings == null ||
        _storedEmbeddings!.isEmpty) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Scanning face…';
    });

    try {
      final XFile xFile = await _cameraController!.takePicture();
      final File imageFile = File(xFile.path);

      final liveEmbedding = await _faceService.extractEmbedding(imageFile);

      if (liveEmbedding == null) {
        setState(() {
          _statusMessage = 'No face detected. Center your face in the frame.';
          _isProcessing = false;
        });
        return;
      }

      final distance =
          _faceService.calculateBestDistance(liveEmbedding, _storedEmbeddings!);
      _lastDistance = distance;

      debugPrint('[FaceVerify] Best distance: $distance '
          '(threshold: ${FaceRecognitionService.verificationThreshold})');

      if (distance < FaceRecognitionService.verificationThreshold) {
        _autoTimer?.cancel();
        _pulseController.stop();
        setState(() {
          _verificationDone = true;
          _verificationSuccess = true;
          _statusMessage = 'Verification Successful!';
          _isProcessing = false;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('role', 'student');
        await prefs.setString('studentId', widget.studentId);
        final verificationTime = DateTime.now().toIso8601String();
        await prefs.setString('lastVerificationTime', verificationTime);

        await Future.delayed(const Duration(milliseconds: 1400));
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
        _attemptCount++;
        if (_attemptCount < 5) {
          setState(() {
            _statusMessage = 'Verifying... (Attempt $_attemptCount/5)';
            _isProcessing = false;
          });
        } else {
          _autoTimer?.cancel();
          setState(() {
            _verificationDone = true;
            _verificationSuccess = false;
            _statusMessage = 'Verification failed. Faces do not match.';
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
        _isProcessing = false;
      });
    }
  }

  // ── Retry ─────────────────────────────────────────────────────────────────

  void _retry() {
    setState(() {
      _verificationDone = false;
      _verificationSuccess = false;
      _lastDistance = null;
      _attemptCount = 0;
      _statusMessage = 'Position your face in the frame.';
    });
    _startAutoVerify();
  }

  void _skipVerification() {
    _autoTimer?.cancel();
    _autoTimer = null;
    _pulseController.stop();
    Navigator.pushReplacementNamed(
      context,
      AppRoutes.studentDashboard,
      arguments: {
        'studentId': widget.studentId,
        'verificationTime': null,
      },
    );
  }

  // ── Dispose ──────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _autoTimer?.cancel();
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
        title: const Text(
          'FACE VERIFICATION',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSubHeader(),
            Expanded(child: _buildCameraArea()),
            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Text(
        'Hi ${widget.studentId}',
        style: const TextStyle(fontSize: 14, color: Colors.black45),
      ),
    );
  }

  Widget _buildCameraArea() {
    // Border colour reflects current state
    Color borderColor = _primary;
    if (_verificationDone) {
      borderColor = _verificationSuccess ? _success : _failure;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      child: _isCameraReady
          ? ScaleTransition(
              scale: _verificationDone
                  ? const AlwaysStoppedAnimation(1.0)
                  : _pulseAnim,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: borderColor, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.18),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: Stack(
                    children: [
                      CameraPreview(_cameraController!),
                      // Overlay on success/fail
                      if (_verificationDone)
                        Container(
                          color: (_verificationSuccess ? _success : _failure)
                              .withValues(alpha: 0.22),
                          child: Center(
                            child: Icon(
                              _verificationSuccess
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color: Colors.white,
                              size: 80,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            )
          : const Center(
              child: CircularProgressIndicator(color: Color(0xFFFF8C61)),
            ),
    );
  }

  Widget _buildBottomPanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 0, 30, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Status message
          Text(
            _statusMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: _verificationDone
                  ? (_verificationSuccess ? _success : _failure)
                  : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),

          // Distance score
          if (_lastDistance != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Score: ${((1 - (_lastDistance! / FaceRecognitionService.verificationThreshold)).clamp(0, 1) * 100).toInt()}%  •  dist=${_lastDistance!.toStringAsFixed(3)}',
                style: const TextStyle(fontSize: 11, color: Colors.black26),
              ),
            ),

          const SizedBox(height: 20),

          // Buttons
          if (_isProcessing)
            const CircularProgressIndicator(color: Color(0xFFFF8C61))
          else if (_verificationDone && !_verificationSuccess)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _retry,
                    icon:
                        const Icon(Icons.refresh_rounded, color: Colors.white),
                    label: const Text(
                      'Try Again',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.clear();
                        if (mounted) {
                          Navigator.pushReplacementNamed(
                              context, AppRoutes.login,
                              arguments: 'student');
                        }
                      },
                      child: const Text(
                        'Back to Login',
                        style: TextStyle(color: Colors.black45, fontSize: 14),
                      ),
                    ),
                    TextButton(
                      onPressed: _skipVerification,
                      child: const Text(
                        'Skip Verification',
                        style: TextStyle(
                            color: Color(0xFFFF7F50),
                            fontSize: 14,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            )
          else if (!_verificationDone)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _verify,
                    icon: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white),
                    label: const Text(
                      'Verify Now',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      disabledBackgroundColor: _primary.withValues(alpha: 0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _skipVerification,
                  child: const Text(
                    'Skip Verification',
                    style: TextStyle(
                        color: Color(0xFFFF7F50),
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.clear();
                    if (mounted) {
                      Navigator.pushReplacementNamed(
                          context, AppRoutes.login,
                          arguments: 'student');
                    }
                  },
                  child: const Text(
                    'Use ID & Password',
                    style: TextStyle(
                        color: Colors.black45,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
