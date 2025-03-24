import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'facultyProfile.dart';

class FacultyDashboard extends StatefulWidget {
  final String facultyId;

  const FacultyDashboard({super.key, required this.facultyId});

  @override
  _FacultyDashboardState createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  Map<String, dynamic>? facultyData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFacultyData();
  }

  Future<void> _fetchFacultyData() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('faculties') // ✅ Corrected Collection Name
          .doc(widget.facultyId)
          .get();

      if (doc.exists) {
        setState(() {
          facultyData = doc.data() as Map<String, dynamic>;
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
        builder: (context) => FacultyProfile(facultyId: widget.facultyId),
      ),
    );
  }

  Widget _buildDashboardButton(String label, String image, Function() onTap, {double imageSize = 80.0}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2D336B),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(2, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(image, width: imageSize, height: imageSize), // ✅ Uses dynamic image size
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
      backgroundColor: const Color(0xFF7886C7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D336B),
        title: const Text("FACULTY DASHBOARD"),
        leading: const Icon(Icons.menu, color: Colors.white),
        actions: const [Icon(Icons.notifications, color: Colors.white)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : facultyData != null
          ? Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // ✅ Profile Section
            Row(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/profile.png'),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    "Hello! ${facultyData!['name']}",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
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
                      "View Profile", 'assets/view_profile.png', _navigateToProfile, imageSize: 100.0),
                  _buildDashboardButton(
                      "Mark Attendance", 'assets/mark_attendance.png', () => _navigateTo('Attendance'), imageSize: 100.0),
                  _buildDashboardButton(
                      "Student Details", 'assets/student_details.png', () => _navigateTo('Student Details'), imageSize: 100.0),
                  _buildDashboardButton(
                      "My Mentees", 'assets/my_mentees.png', () => _navigateTo('Mentees'), imageSize: 100.0),
                ],
              ),
            ),
          ],
        ),
      )
          : const Center(
          child: Text("Faculty data not found!",
              style: TextStyle(color: Colors.white, fontSize: 18))),
    );
  }
}
