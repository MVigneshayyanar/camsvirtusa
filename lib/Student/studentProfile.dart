import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'studentDashboard.dart';

class StudentProfile extends StatefulWidget {
  final String studentId;
  const StudentProfile({Key? key, required this.studentId}) : super(key: key);

  @override
  _StudentProfileState createState() => _StudentProfileState();
}

class _StudentProfileState extends State<StudentProfile> {
  Map<String, dynamic>? studentData;
  Map<String, dynamic>? mentorData;
  bool _isLoading = true;

  static const Color _orange = Color(0xFFFF7F50);
  static const Color _darkGray = Color(0xFF2D336B);
  static const Color _cardGray = Color(0xFF37474F);
  static const Color _lightGrayBg = Color(0xFFF0F0F0);

  @override
  void initState() {
    super.initState();
    _fetchData();
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

      final mentorQuery = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('faculties')
          .collection('all_faculties')
          .where('mentees', arrayContains: widget.studentId)
          .limit(1)
          .get();

      if (mentorQuery.docs.isNotEmpty) {
        mentorData = mentorQuery.docs.first.data();
      }
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

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          Flexible(
            child: Text(
              value ?? '—',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDashboard(studentId: widget.studentId),
      ),
    );
  }

  void _goToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: _orange,
            title: const Text("Search", style: TextStyle(color: Colors.white)),
          ),
          body: const Center(child: Text("Search Page")),
        ),
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(), // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                _performLogout();
              },
              child: const Text('Logout', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _performLogout() async {
    try {
      // Clear all stored user data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Navigate to login page and clear all previous routes
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/roleSelection', // Replace with your login route
            (Route<dynamic> route) => false,
      );

      print("User logged out successfully - SharedPreferences cleared");

    } catch (e) {
      print("Error during logout: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout error: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
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
              onPressed: _goToDashboard,
            ),
            IconButton(
              icon: Image.asset(
                "assets/account.png",
                height: screenWidth > 600 ? 30 : 26, // Responsive height
              ),
              onPressed: () {}, // Already on profile page
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;
    final double screenHeight = mediaQuery.size.height;

    final name = studentData?['name']?.toString() ?? '';
    final id = studentData?['id']?.toString();
    final department = studentData?['department']?.toString();
    final studentClass = studentData?['class']?.toString();
    final email = studentData?['email']?.toString();
    final mentorId = mentorData?['id']?.toString();
    final mentorName = mentorData?['name']?.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'STUDENT PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth > 600 ? 30 : 24, // Responsive title
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFFF7F50),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: screenHeight > 600 ? 100 : 80, // Responsive bottom padding
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: _orange,
              padding: EdgeInsets.only(
                bottom: screenHeight > 600 ? 40 : 30, // Responsive padding
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: screenWidth > 600 ? 60 : 50, // Responsive avatar size
                    backgroundColor: Colors.white,
                    backgroundImage: AssetImage('assets/account.png'),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      text: 'Hello! ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: screenWidth > 600 ? 18 : 16, // Responsive font
                      ),
                      children: [
                        TextSpan(
                          text: name.toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: screenWidth > 600 ? 22 : 20, // Responsive font
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: screenHeight > 600 ? 20 : 16),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 600 ? 32 : 16, // Responsive padding
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.all(screenWidth > 600 ? 20 : 16),
                child: Column(
                  children: [
                    _infoRow('Name', name),
                    _infoRow('College ID', id),
                    _infoRow('Email', email),
                    _infoRow('Department', department),
                    _infoRow('Class', studentClass),
                    _infoRow('Mentor ID', mentorId),
                    _infoRow('Mentor Name', mentorName),
                  ],
                ),
              ),
            ),
            SizedBox(height: screenHeight > 600 ? 20 : 16),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
      floatingActionButton: Container(
        width: screenWidth > 600 ? 120 : 100, // Responsive width
        height: screenWidth > 600 ? 45 : 40, // Responsive height
        child: FloatingActionButton(
          onPressed: _logout,
          backgroundColor: const Color(0xFFFF7F50),
          elevation: 0, // Remove shadow
          child: Text(
            'Log out',
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth > 600 ? 14 : 12, // Responsive font size
            ),
          ),
        ),
      ),
    );
  }
}