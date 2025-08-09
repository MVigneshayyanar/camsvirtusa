import 'package:camsvirtusa/Student/studentLeave.dart';
import 'package:camsvirtusa/Student/studentOd.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'studentProfile.dart';
import 'studentAttendance.dart';

class StudentDashboard extends StatefulWidget {
  final String studentId;

  const StudentDashboard({Key? key, required this.studentId}) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  Map<String, dynamic>? studentData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _loadAllData() async {
    await Future.delayed(const Duration(seconds: 2)); // Simulating data loading

    // Hardcoded student data for demonstration
    // setState(() {
    //   studentData = {
    //     'name': studentId,
    //     'attendancePercent': 96,
    //   };
    //   _isLoading = false;
    // });
  }

  Future<void> _fetchData() async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .get();

      if (!studentDoc.exists) throw Exception("Student not found");

      studentData = studentDoc.data();

    } catch (e) {
      print("Error fetching data: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error fetching profile: $e")),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void navigateToAttendance(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentAttendancePage(),
      ),
    );
  }

  void navigateToTimeTable(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentAttendancePage(),
      ),
    );
  }

  void navigateToODForm(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnDutyFormPage(),
      ),
    );
  }

  void navigateToLeaveForm(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaveApplicationForm(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = studentData?['name']?.toString() ?? '';
    var p=60;
    final attendancePercent = (studentData?['attendancePercent'] ?? p).toInt();

    return Scaffold(
      backgroundColor: Colors.white, // Set scaffold background to white
      appBar: AppBar(
        title: const Center(
          child: Text('STUDENT DASHBOARD', style: TextStyle(color: Colors.white)),
        ),
        backgroundColor: const Color(0xFFFF7F50),
        elevation: 0,
        automaticallyImplyLeading: false, // Removes the back button
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white, // Container background is now white
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // User Welcome Section
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: const AssetImage('assets/account.png'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text("Welcome $name!", style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Attendance Section
              Row(
                children: [
                  const Expanded(child: Text("Attendance:", style: TextStyle(color: Colors.black))),
                  Container(
                    width: 200,
                    height: 20,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.red),
                    child: Stack(
                      children: [
                        Container(
                          width: 196 * (p / 100),
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: const Color(0xFF32C425)),
                        ),
                        Positioned(
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.red),
                            width: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text("$attendancePercent%", style: const TextStyle(color: Colors.black)),
                ],
              ),
              const SizedBox(height: 24),

              // Dashboard Grid
              _buildDashboardGrid(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDashboardGrid(BuildContext context) {
    return Expanded(
      child: GridView.count(
        padding: const EdgeInsets.all(20.0),
        crossAxisCount: 2,
        children: [
          _buildDashboardCard(
            context,
            label: "TIME TABLE",
            imagePath: "assets/timetable_ad.png",
            onTap: () => navigateToTimeTable("Time Table"),
          ),
          _buildDashboardCard(
            context,
            label: "ATTENDANCE",
            imagePath: "assets/Attendance.png",
            onTap: () => navigateToAttendance("Attendance"),
          ),
          _buildDashboardCard(
            context,
            label: "ON DUTY FORM",
            imagePath: "assets/ODForm.png",
            onTap: () => navigateToODForm("On Duty Form"),
          ),
          _buildDashboardCard(
            context,
            label: "LEAVE FORM",
            imagePath: "assets/LeaveForm.png",
            onTap: () => navigateToLeaveForm("Leave Form"),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, {required String label, required String imagePath, required VoidCallback onTap}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: const Color(0xFF36454F), // Box color updated
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 60), // Adjust height as necessary
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16)), // Text color updated
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: Image.asset("assets/search.png", height: 26),
            onPressed: () {},
          ),
          IconButton(
            icon: Image.asset("assets/homeLogo.png", height: 32),
            onPressed: () {},
          ),
          IconButton(
            icon: Image.asset("assets/account.png", height: 26),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentProfile(studentId: widget.studentId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}