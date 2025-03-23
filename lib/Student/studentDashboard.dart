import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Widget _buildDashboardButton(String label, String image, Function() onTap) {
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
            Image.asset(image, width: 50, height: 50),
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
        title: const Text("Student Dashboard"),
        leading: Icon(Icons.menu, color: Colors.white),
        actions: [Icon(Icons.notifications, color: Colors.white)],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : studentData != null
          ? Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Section
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/profile.png'),
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

            // Attendance Progress Bar
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

            // Dashboard Buttons Grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                children: [
                  _buildDashboardButton(
                      "View Profile", 'assets/profile_icon.png', () => _navigateTo('Profile')),
                  _buildDashboardButton(
                      "Check Attendance", 'assets/attendance.png', () => _navigateTo('Attendance')),
                  _buildDashboardButton(
                      "On Duty Form", 'assets/od_form.png', () => _navigateTo('On Duty')),
                  _buildDashboardButton(
                      "Leave Form", 'assets/leave_form.png', () => _navigateTo('Leave')),
                ],
              ),
            ),
          ],
        ),
      )
          : const Center(
          child: Text("Student data not found!",
              style: TextStyle(color: Colors.white, fontSize: 18))),
    );
  }
}
