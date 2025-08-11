import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../Student/studentTimetable.dart';
import 'facultyProfile.dart';
import 'MarkAttendance.dart';
import '';

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

      final doc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('faculties')
          .collection('all_faculties')
          .doc(widget.facultyId)
          .get();
      if (doc.exists) {
        setState(() {
          facultyData = doc.data();
          _isLoading = false;
        });
      } else {
        setState(() {
          facultyData = {'name': 'Unknown Faculty'};
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        facultyData = {'name': 'Error loading data'};
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load faculty data: $e')),
      );
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacultyProfile(facultyId: widget.facultyId),
      ),
    );
  }

  void _navigateToMarkAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkAttendance(facultyId: widget.facultyId),
      ),
    );
  }

  void navigateToTimeTable() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimeTablePage(studentId:widget.facultyId),
      ),
    );
  }

  void _navigateToMentees() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('My Mentees'),
            backgroundColor: const Color(0xFFFF7F50),
          ),
          body: const Center(child: Text('My Mentees Page', style: TextStyle(fontSize: 24))),
        ),
      ),
    );
  }

  void _navigateToRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Requests'),
            backgroundColor: const Color(0xFFFF7F50),
          ),
          body: const Center(child: Text('Requests Page', style: TextStyle(fontSize: 24))),
        ),
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
      decoration: const BoxDecoration(
        color: Color(0xFFE5E5E5),
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
              onPressed: () {
                // Already on home, maybe refresh or do nothing
              },
            ),
            IconButton(
              icon: Image.asset(
                "assets/account.png",
                height: screenWidth > 600 ? 30 : 26, // Responsive height
              ),
              onPressed: _navigateToProfile,
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

    final name = facultyData?['name']?.toString() ?? '';

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Center(
          child: Text(
            'FACULTY DASHBOARD',
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
        child: Padding(
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
              SizedBox(height: screenHeight > 600 ? 48 : 32),

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
            onTap: navigateToTimeTable,
          ),
          _buildDashboardCard(
            context,
            label: "MARK ATTENDANCE",
            imagePath: "assets/Attendance.png",
            onTap: _navigateToMarkAttendance,
          ),
          _buildDashboardCard(
            context,
            label: "MY MENTEES",
            imagePath: "assets/MyMentees.png",
            onTap: _navigateToMentees,
          ),
          _buildDashboardCard(
            context,
            label: "REQUESTS",
            imagePath: "assets/requests.png",
            onTap: _navigateToRequests,
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