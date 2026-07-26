import 'package:camsvirtusa/Shared/newsScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'studentDashboard.dart';
import '../Startup/routes.dart';

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
      print(studentDoc);

      if (!studentDoc.exists) throw Exception("Student not found");

      studentData = studentDoc.data();
      print(studentData);

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
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
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

  void _goToNews() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewsScreen()),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logout Icon
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Colors.red,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                const Text(
                  "Confirm Logout",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Description
                const Text(
                  "Are you sure you want to log out of your account?",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.black12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Cancel",
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _performLogout();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Logout",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
        AppRoutes.login, // Redirect to login after logout
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
        backgroundColor: const Color(0xFFF97316),
        automaticallyImplyLeading: false,
        title: Text(
          'STUDENT PROFILE',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.only(
                bottom:
                    screenHeight > 600 ? 100 : 80, // Responsive bottom padding
              ),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF97316),
                    padding: EdgeInsets.only(
                      bottom:
                          screenHeight > 600 ? 40 : 30, // Responsive padding
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: screenWidth > 600
                              ? 60
                              : 50, // Responsive avatar size
                          backgroundColor: Colors.white,
                          child: Icon(
                            PhosphorIconsRegular.user,
                            size: screenWidth > 600 ? 60 : 50,
                            color: const Color(0xFFFF8C61),
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: TextSpan(
                            text: 'Hello! ',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: screenWidth > 600
                                  ? 18
                                  : 16, // Responsive font
                            ),
                            children: [
                              TextSpan(
                                text: name.toUpperCase(),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: screenWidth > 600
                                      ? 22
                                      : 20, // Responsive font
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
                      horizontal:
                          screenWidth > 600 ? 32 : 16, // Responsive padding
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
      floatingActionButton: Container(
        width: screenWidth > 600 ? 120 : 100, // Responsive width
        height: screenWidth > 600 ? 45 : 40, // Responsive height
        child: FloatingActionButton(
          onPressed: _logout,
          backgroundColor: const Color(0xFFF97316),
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
