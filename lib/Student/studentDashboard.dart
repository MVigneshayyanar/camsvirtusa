import 'package:flutter/material.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF76C7C0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A7F77),
        title: const Text("Student Dashboard"),
      ),
      body: Center(
        child: const Text(
          "Welcome to Student Dashboard",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
