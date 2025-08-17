import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeSplash();
  }

  void _initializeSplash() {
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _checkAndNavigate();
      }
    });
  }

  Future<void> _checkAndNavigate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      final String? role = prefs.getString('role');
      final String? studentId = prefs.getString('studentId');
      final String? facultyId = prefs.getString('facultyId');
      final String? facultyRole = prefs.getString('facultyRole');

      if (!mounted) return;

      if (isLoggedIn && role != null) {
        if (role == 'student' && studentId != null && studentId.isNotEmpty) {
          Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.studentDashboard,
                  (route) => false,
              arguments: studentId
          );
          return;
        } else if (role == 'faculty' && facultyId != null && facultyId.isNotEmpty) {
          if (facultyRole == 'admin') {
            Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.adminDashboard,
                    (route) => false
            );
          } else {
            Navigator.pushNamedAndRemoveUntil(
                context,
                AppRoutes.facultyDashboard,
                    (route) => false,
                arguments: facultyId
            );
          }
          return;
        }
      }

      // Default navigation
      Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.roleSelection,
              (route) => false
      );
    } catch (e) {
      // Handle any errors by navigating to role selection
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.roleSelection,
                (route) => false
        );
      }
    }
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
            errorBuilder: (context, error, stackTrace) {
              return Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.error, size: 50),
              );
            },
          ),
        ),
      ),
    );
  }
}
