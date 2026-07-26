import 'package:camsvirtusa/Shared/newsScreen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../Startup/routes.dart';

class FacultyProfile extends StatefulWidget {
  final String facultyId;

  const FacultyProfile({Key? key, required this.facultyId}) : super(key: key);

  @override
  _FacultyProfileState createState() => _FacultyProfileState();
}

class _FacultyProfileState extends State<FacultyProfile> {
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

  void _goToNews() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewsScreen()),
    );
  }

  void _goToDashboard() {
    Navigator.pop(context);
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
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      Navigator.of(context).pushNamedAndRemoveUntil(
        AppRoutes.login,
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'FACULTY PROFILE',
            style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
          ),
          automaticallyImplyLeading: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Extract data from facultyData or use defaults
    final employeeName = facultyData?['name']?.toString() ?? 'Unknown Faculty';
    final jobTitle = facultyData?['jobTitle']?.toString() ?? 'Associate Professor';
    final department = facultyData?['department']?.toString() ?? 'M.Tech CSE';
    final employeeId = facultyData?['employeeId']?.toString() ?? widget.facultyId;
    final highestQualification = facultyData?['qualification']?.toString() ?? 'PHD';
    final dateOfJoining = facultyData?['dateOfJoining']?.toString() ?? '12/05/2010';
    final dateOfBirth = facultyData?['dateOfBirth']?.toString() ?? '02.05.1975';
    final emailId = facultyData?['email']?.toString() ?? 'nithya.cj@siram.co';
    final contactNo = facultyData?['contactNo']?.toString() ?? '7344507768';
    final address = facultyData?['address']?.toString() ?? '12 New Colony, XYZ city - 045';
    final profileImageUrl = facultyData?['profileImageUrl']?.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'FACULTY PROFILE',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Profile Card Area
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                    padding: EdgeInsets.all(screenWidth > 600 ? 24.0 : 20.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: screenWidth > 600 ? 35 : 30,
                          backgroundColor: const Color(0xFFFF8C61).withOpacity(0.12),
                          backgroundImage: profileImageUrl != null
                              ? NetworkImage(profileImageUrl)
                              : null,
                          child: profileImageUrl == null
                              ? Icon(
                                  PhosphorIconsRegular.user,
                                  size: screenWidth > 600 ? 40 : 35,
                                  color: const Color(0xFFFF8C61),
                                )
                              : null,
                        ),
                        SizedBox(width: screenWidth > 600 ? 20 : 16),
                        // Greeting and Name
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hello!',
                                style: TextStyle(
                                  fontSize: screenWidth > 600 ? 16 : 14,
                                  fontStyle: FontStyle.italic,
                                  color: Colors.black54,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                employeeName,
                                style: TextStyle(
                                  fontSize: screenWidth > 600 ? 20 : 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenWidth > 600 ? 32 : 24),

                  // Faculty Details Section
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth > 600 ? 24.0 : 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FACULTY DETAILS',
                          style: TextStyle(
                            fontSize: screenWidth > 600 ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4B5563),
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: screenWidth > 600 ? 16 : 12),
                        _buildInfoCard('Job Title : $jobTitle', screenWidth),
                        _buildInfoCard('Department : $department', screenWidth),
                        _buildInfoCard('Employee ID : $employeeId', screenWidth),
                      ],
                    ),
                  ),

                  SizedBox(height: screenWidth > 600 ? 32 : 24),

                  // Personal Details Section
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth > 600 ? 24.0 : 16.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PERSONAL DETAILS',
                          style: TextStyle(
                            fontSize: screenWidth > 600 ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF4B5563),
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: screenWidth > 600 ? 16 : 12),
                        _buildInfoCard('Highest Qualification : $highestQualification', screenWidth),
                        _buildInfoCard('Date of Joining : $dateOfJoining', screenWidth),
                        _buildInfoCard('Date of Birth : $dateOfBirth', screenWidth),
                        _buildInfoCard('E-mail ID : $emailId', screenWidth),
                        _buildInfoCard('Contact No : $contactNo', screenWidth),
                        _buildInfoCard('Address : $address', screenWidth),
                      ],
                    ),
                  ),

                  const SizedBox(height: 80), // Space for bottom navigation
                ],
              ),
            ),
          ),
        ],
      ),

      floatingActionButton: SizedBox(
        width: screenWidth > 600 ? 120 : 100,
        height: screenWidth > 600 ? 45 : 40,
        child: FloatingActionButton(
          onPressed: _logout,
          child: Text(
            'Log out',
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth > 600 ? 14 : 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String text, double screenWidth) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: screenWidth > 600 ? 12 : 8),
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 16 : 12,
        vertical: screenWidth > 600 ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF36454F),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: screenWidth > 600 ? 15 : 13,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
