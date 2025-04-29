import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'studentProfile.dart';
import 'studentAttendance.dart';

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

  Widget _buildDashboardButton(
      String label, String image, Function() onTap, {double imageSize = 50.0}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D336B),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 6,
              offset: Offset(2, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(image, width: imageSize, height: imageSize),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D336B),
        title: const Text("Student Dashboard"),
        leading: const Icon(Icons.menu, color: Colors.white),
        actions: const [Icon(Icons.notifications, color: Colors.white)],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF7886C7), // Original color scheme
          image: DecorationImage(
            image: AssetImage('assets/scribbles_texture.png'), // Texture image path
            fit: BoxFit.cover, // Ensures it spans the full background
            colorFilter: ColorFilter.mode(
              Color(0xFF7886C7).withOpacity(0.7), // Blends texture with the color
              BlendMode.srcATop,
            ),
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : studentData != null
            ? Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // ✅ Profile Section
              Row(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey,
                    child: Icon(
                      Icons.account_circle,
                      size: 80,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Text(
                      "Welcome ${studentData!['name']}...!",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ✅ Attendance Progress Bar
              Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: 0.96, // Example: 96%
                      backgroundColor: Colors.red,
                      color: Colors.green,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "96%",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.circle, color: Colors.green, size: 12),
                  SizedBox(width: 5),
                  Text("PRESENT"),
                  SizedBox(width: 15),
                  Icon(Icons.circle, color: Colors.red, size: 12),
                  SizedBox(width: 5),
                  Text("ABSENT"),
                ],
              ),
              const SizedBox(height: 30),

              // ✅ Dashboard Buttons Grid
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  children: [
                    _buildDashboardButton(
                        "View Profile",
                        'assets/view_profile.png',
                        _navigateToProfile,
                        imageSize: 100.0),
                    _buildDashboardButton(
                        "Check Attendance",
                        'assets/check_attendance.png',
                            () => _navigateTo('Attendance'),
                        imageSize: 100.0),
                    _buildDashboardButton(
                        "On Duty Form",
                        'assets/on_duty.png',
                            () => _navigateTo('On Duty'),
                        imageSize: 100.0),
                    _buildDashboardButton(
                        "Leave Form",
                        'assets/leave_form.png',
                            () => _navigateTo('Leave'),
                        imageSize: 100.0),
                  ],
                ),
              ),
            ],
          ),
        )
            : const Center(
          child: Text(
            "Student data not found!",
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
    );
  }
}
