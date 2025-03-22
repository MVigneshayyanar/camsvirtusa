import 'package:flutter/material.dart';

class FacultyDashboard extends StatelessWidget {
  final String facultyId;

  const FacultyDashboard({super.key,required this.facultyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7886C7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D336B),
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
