// lib/Startup/splashScreen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes.dart'; // adjust path if needed; if file is in same folder use 'routes.dart'

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAndNavigate();
  }

  Future<void> _checkAndNavigate() async {
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? role = prefs.getString('role');
    final String? studentId = prefs.getString('studentId');
    final String? facultyId = prefs.getString('facultyId');
    final String? facultyRole = prefs.getString('facultyRole'); // admin or faculty

    // small splash delay so logo shows
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    if (isLoggedIn && role != null) {
      if (role == 'student' && studentId != null && studentId.isNotEmpty) {
        Navigator.pushReplacementNamed(context, AppRoutes.studentDashboard, arguments: studentId);
        return;
      } else if (role == 'faculty' && facultyId != null && facultyId.isNotEmpty) {
        // send admin to adminDashboard, otherwise facultyDashboard (AppRoutes handles arguments)
        if (facultyRole == 'admin') {
          Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
        } else {
          Navigator.pushReplacementNamed(context, AppRoutes.facultyDashboard, arguments: facultyId);
        }
        return;
      }
    }

    // default: not logged in or missing id/role → go to role selection
    Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE),
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            "assets/logo.png",
            width: 150,
          ),
        ),
      ),
    );
  }
}
