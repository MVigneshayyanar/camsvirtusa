// lib/Authentication/facultyLogin.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Startup/routes.dart';

class FacultyLoginScreen extends StatefulWidget {
  const FacultyLoginScreen({super.key});

  @override
  _FacultyLoginScreenState createState() => _FacultyLoginScreenState();
}

class _FacultyLoginScreenState extends State<FacultyLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _maybeAutoRedirect();
  }

  Future<void> _maybeAutoRedirect() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final role = prefs.getString('role');
    final facultyId = prefs.getString('facultyId');
    final facultyRole = prefs.getString('facultyRole'); // 'admin' or 'faculty'

    if (isLoggedIn && role == 'faculty') {
      if (!mounted) return;
      if (facultyRole == 'admin') {
        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
      } else if (facultyId != null) {
        Navigator.pushReplacementNamed(context, AppRoutes.facultyDashboard, arguments: facultyId);
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    try {
      final QuerySnapshot query = await FirebaseFirestore.instance
          .collection('faculties')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final userDoc = query.docs.first;
        final userData = userDoc.data() as Map<String, dynamic>;

        final String? storedPassword = userData['password']?.toString();
        final String? role = userData['role']?.toString();
        final String facultyId = userDoc.id;

        if (storedPassword == null || role == null) {
          setState(() => _errorMessage = "Invalid account data.");
        } else if (storedPassword == password) {
          // ======= SAVE LOGIN STATE =======
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('role', 'faculty');
          await prefs.setString('facultyId', facultyId);
          await prefs.setString('facultyRole', role); // so Splash can route admin vs faculty

          if (!mounted) return;
          if (role == 'admin') {
            Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
          } else {
            Navigator.pushReplacementNamed(context, AppRoutes.facultyDashboard, arguments: facultyId);
          }
        } else {
          setState(() => _errorMessage = "Invalid password. Try again.");
        }
      } else {
        setState(() => _errorMessage = "User not found. Check your email.");
      }
    } catch (e) {
      setState(() => _errorMessage = "Login failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // (UI same as yours)
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: /* your existing UI, unchanged */ Center(child: Text('Faculty Login UI here')),
      ),
    );
  }
}
