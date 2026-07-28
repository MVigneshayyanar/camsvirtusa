import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../Startup/routes.dart';
import '../Services/face_recognition_service.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
class LoginScreen extends StatefulWidget {
  // initialRole kept for backwards compatibility but is no longer used for UI
  final String initialRole;

  const LoginScreen({super.key, this.initialRole = 'student'});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _maybeAutoRedirect();
  }

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// If already logged in, redirect to face verification (for students) or dashboard (for faculty)
  Future<void> _maybeAutoRedirect() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final role = prefs.getString('role');

    if (isLoggedIn && role != null) {
      if (role == 'student') {
        final studentId = prefs.getString('studentId');
        if (studentId != null && mounted) {
          // Require face verification every time they open the app
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.faceVerification,
            arguments: studentId,
          );
        }
      } else if (role == 'faculty') {
        final facultyId = prefs.getString('facultyId');
        if (facultyId != null && mounted) {
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.facultyDashboard,
            arguments: facultyId,
          );
        }
      }
    }
  }

  /// Tries to authenticate as a student first, then as a faculty.
  /// Role is determined automatically from Firestore — no tab selection needed.
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String enteredId = _idController.text.trim().toUpperCase();
    final String password = _passwordController.text.trim();

    if (enteredId.isEmpty || password.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please enter your ID and password.';
      });
      return;
    }

    try {
      // --- Try STUDENT login first ---
      final studentDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(enteredId)
          .get();

      if (studentDoc.exists) {
        final data = studentDoc.data() as Map<String, dynamic>;
        if (data['password'] == password) {
          // Fetch hardware device ID for binding
          String? deviceId;
          final deviceInfoPlugin = DeviceInfoPlugin();
          try {
            if (Platform.isAndroid) {
              final androidInfo = await deviceInfoPlugin.androidInfo;
              deviceId = androidInfo.id;
            } else if (Platform.isIOS) {
              final iosInfo = await deviceInfoPlugin.iosInfo;
              deviceId = iosInfo.identifierForVendor;
            }
          } catch (e) {
            print("Failed to get device ID: $e");
          }

          if (deviceId != null) {
            final storedDeviceId = data['deviceId'];
            if (storedDeviceId == null || storedDeviceId.toString().isEmpty) {
              // First login on this device: Bind it
              await FirebaseFirestore.instance
                  .collection('colleges')
                  .doc('students')
                  .collection('all_students')
                  .doc(enteredId)
                  .update({'deviceId': deviceId});
            } else if (storedDeviceId != deviceId) {
              // Already bound to a different device
              setState(() {
                _errorMessage =
                    'Access Denied. This account is bound to another device. Please use your registered phone.';
              });
              return;
            }
          }

          // Student authenticated — proceed to face verification
          final faceService = FaceRecognitionService();
          final hasEnrolled = await faceService.hasEnrolledFace(enteredId);
          faceService.dispose();

          if (!mounted) return;
          if (hasEnrolled) {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.faceVerification,
              arguments: enteredId,
            );
          } else {
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.faceEnrollment,
              arguments: enteredId,
            );
          }
          return;
        } else {
          // ID exists but password wrong — no need to try faculty
          setState(() => _errorMessage = 'Incorrect password.');
          return;
        }
      }

      // --- ID not found in students, try FACULTY login ---
      final facultyDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('faculties')
          .collection('all_faculties')
          .doc(enteredId)
          .get();

      if (facultyDoc.exists) {
        final data = facultyDoc.data() as Map<String, dynamic>;
        if (data['password'] == password) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('role', 'faculty');
          await prefs.setString('facultyId', enteredId);

          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.facultyDashboard,
            arguments: enteredId,
          );
        } else {
          setState(() => _errorMessage = 'Incorrect password.');
        }
      } else {
        // Not found in either collection
        setState(() => _errorMessage = 'ID not found. Please check your credentials.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Login failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Branding icon
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C61).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsRegular.identificationBadge,
                    size: 80,
                    color: const Color(0xFFFF8C61),
                  ),
                ),
                const SizedBox(height: 25),

                const Text(
                  'WELCOME BACK',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in with your institution ID',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 40),

                // ID Field
                TextField(
                  controller: _idController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Student / Faculty ID',
                    filled: true,
                    fillColor: const Color(0xFFE5E5E5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    prefixIcon: Icon(
                      PhosphorIconsRegular.identificationCard,
                      color: Colors.black54,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Password Field
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Password',
                    filled: true,
                    fillColor: const Color(0xFFE5E5E5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    prefixIcon: Icon(
                      PhosphorIconsRegular.lock,
                      color: Colors.black54,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? PhosphorIconsRegular.eyeSlash
                            : PhosphorIconsRegular.eye,
                        color: Colors.black54,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),


                const SizedBox(height: 15),

                _isLoading
                    ? const CircularProgressIndicator(color: Color(0xFFFF8C61))
                    : SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF8C61),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
