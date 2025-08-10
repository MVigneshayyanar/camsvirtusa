import 'package:camsvirtusa/Student/studentLeave.dart';
import 'package:camsvirtusa/Student/studentOd.dart';
import 'package:camsvirtusa/Student/studentTimetable.dart';
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
        builder: (context) => TimeTablePage(studentId:widget.studentId),
      ),
    );
  }

  void navigateToODForm(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnDutyFormPage(studentId:widget.studentId),
      ),
    );
  }

  void navigateToLeaveForm(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaveApplicationForm(studentId: widget.studentId),
      ),
    );
  }

  void _goToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFFFF7F50),
            title: const Text("Search", style: TextStyle(color: Colors.white)),
          ),
          body: const Center(child: Text("Search Page")),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    final mediaQuery = MediaQuery.of(context);
    final double bottomSafeArea = mediaQuery.padding.bottom;
    final double screenWidth = mediaQuery.size.width;

    return Container(
      height: 70 + bottomSafeArea, // Add safe area to prevent overlap
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSafeArea), // Add bottom padding for safe area
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Image.asset(
                "assets/search.png",
                height: screenWidth > 600 ? 30 : 26, // Responsive height
              ),
              onPressed: _goToSearch,
            ),
            IconButton(
              icon: Image.asset(
                "assets/homeLogo.png",
                height: screenWidth > 600 ? 36 : 32, // Responsive height
              ),
              onPressed: () {}, // Already on dashboard
            ),
            IconButton(
              icon: Image.asset(
                "assets/account.png",
                height: screenWidth > 600 ? 30 : 26, // Responsive height
              ),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get media query data for responsive design
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double screenWidth = mediaQuery.size.width;
    final double bottomSafeArea = mediaQuery.padding.bottom;

    final name = studentData?['name']?.toString() ?? '';
    var p = 60;
    final attendancePercent = (studentData?['attendancePercent'] ?? p).toInt();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Center(
          child: Text(
            'STUDENT DASHBOARD',
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth > 600 ? 30 : 22, // Responsive title size
            ),
          ),
        ),
        backgroundColor: const Color(0xFFFF7F50),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth > 600 ? 24 : 16, // Responsive padding
            vertical: 16,
          ),
          child: Column(
            children: [
              // User Welcome Section
              Row(
                children: [
                  CircleAvatar(
                    radius: screenWidth > 600 ? 35 : 30, // Responsive avatar size
                    backgroundImage: const AssetImage('assets/account.png'),
                  ),
                  SizedBox(width: screenWidth > 600 ? 20 : 16),
                  Expanded(
                    child: Text(
                      "Welcome $name...!!",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth > 600 ? 22 : 18, // Responsive font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight > 600 ? 32 : 24),

              // Attendance Section
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Attendance:",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth > 600 ? 20 : 18, // Responsive font size
                      ),
                    ),
                  ),
                  Container(
                    width: screenWidth > 600 ? 250 : 200, // Responsive progress bar width
                    height: screenWidth > 600 ? 25 : 20, // Responsive height
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.red,
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: (screenWidth > 600 ? 246 : 196) * (p / 100),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFF32C425),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Colors.red,
                            ),
                            width: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "$attendancePercent%",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: screenWidth > 600 ? 16 : 14, // Responsive font size
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight > 600 ? 32 : 24),

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
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;
    final double screenHeight = mediaQuery.size.height;

    return Expanded(
      child: GridView.count(
        padding: EdgeInsets.all(screenWidth > 600 ? 24.0 : 16.0), // Responsive padding
        crossAxisCount: screenWidth > 800 ? 3 : 2, // More columns on larger screens
        crossAxisSpacing: screenWidth > 600 ? 20 : 16, // Responsive spacing
        mainAxisSpacing: screenWidth > 600 ? 20 : 16,
        childAspectRatio: screenWidth > 600 ? 1.1 : 1.0, // Better aspect ratio on tablets
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
    final screenWidth = MediaQuery.of(context).size.width;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(screenWidth > 600 ? 15 : 10), // Responsive border radius
      ),
      color: const Color(0xFF36454F),
      elevation: screenWidth > 600 ? 6 : 4, // Responsive elevation
      child: InkWell(
        borderRadius: BorderRadius.circular(screenWidth > 600 ? 15 : 10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(screenWidth > 600 ? 16 : 12), // Responsive padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                imagePath,
                height: screenWidth > 600 ? 80 : 60, // Responsive image size
              ),
              SizedBox(height: screenWidth > 600 ? 12 : 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth > 600 ? 18 : 16, // Responsive font size
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}