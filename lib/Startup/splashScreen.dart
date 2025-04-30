import 'package:flutter/material.dart';
import 'dart:async';
import '../Startup/routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEEEEE), // Light teal background
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15), // Apply border radius
          child: Image.asset(
            "assets/logo.png",
            width: 150,
          ),
        ),
      ),
    );
  }
}
