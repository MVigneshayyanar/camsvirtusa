import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'studentProfile.dart'; // Import Profile Page

class StudentDashboard extends StatefulWidget {
  final String studentId;

  const StudentDashboard({super.key, required this.studentId});

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  Map<String, dynamic>? studentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .get();

      if (doc.exists) {
        setState(() {
          studentData = doc.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateTo(String page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(page)),
          body: Center(
            child: Text(
              '$page Page',
              style: const TextStyle(fontSize: 24),
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentProfile(studentId: widget.studentId),
      ),
    );
  }

  Widget _buildDashboardButton(String label, IconData icon, Function() onTap) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF2A7F77),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
      ),
      icon: Icon(icon),
      label: Text(label),
      onPressed: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF76C7C0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A7F77),
        title: const Text("Student Dashboard"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : studentData != null
          ? Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Name: ${studentData!['name']}",
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            Text(
              "Email: ${studentData!['email']}",
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            Text(
              "Student ID: ${widget.studentId}",
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 30),
            _buildDashboardButton(
                "View Attendance", Icons.check, () => _navigateTo('Attendance')),
            const SizedBox(height: 10),
            _buildDashboardButton(
                "View Timetable", Icons.calendar_today, () => _navigateTo('Timetable')),
            const SizedBox(height: 10),
            _buildDashboardButton(
                "Request OD", Icons.assignment, () => _navigateTo('Request OD')),
            const SizedBox(height: 10),
            _buildDashboardButton(
                "Request Leave", Icons.event_busy, () => _navigateTo('Request Leave')),
            const SizedBox(height: 10),
            _buildDashboardButton("View Profile", Icons.person, _navigateToProfile),
          ],
        ),
      )
          : const Center(
          child: Text("Student data not found!",
              style: TextStyle(color: Colors.white, fontSize: 18))),
    );
  }
}
