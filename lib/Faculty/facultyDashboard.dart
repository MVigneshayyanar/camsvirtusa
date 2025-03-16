import 'package:flutter/material.dart';

class FacultyDashboard extends StatelessWidget {
  const FacultyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF76C7C0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A7F77),
        title: const Text("faculty Dashboard"),
      ),
      body: Center(
        child: const Text(
          "Welcome to faculty Dashboard",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
