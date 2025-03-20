import 'package:flutter/material.dart';

class FacultyDashboard extends StatelessWidget {
  final String facultyId;

  const FacultyDashboard({super.key, required this.facultyId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Faculty Dashboard"),
        backgroundColor: const Color(0xFF2A7F77),
      ),
      body: Center(
        child: Text(
          "Welcome, Faculty ID: $facultyId",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
