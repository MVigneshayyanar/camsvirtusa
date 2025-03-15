import 'package:flutter/material.dart';
import 'routes.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(seconds: 3), () {
      Navigator.pushReplacementNamed(context, AppRoutes.roleSelection);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF76C7C0),
      body: Center(
        child: Image.asset('assets/logo.png', width: 120),
      ),
    );
  }
}
