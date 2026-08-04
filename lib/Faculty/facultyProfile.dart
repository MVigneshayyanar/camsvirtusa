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
                    color: const Color(0xFFFF7F50).withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: Color(0xFFFF7F50),
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
                          backgroundColor: const Color(0xFFFF7F50),
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
          backgroundColor: const Color(0xFFFF7F50),
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
    final jobTitle =
        facultyData?['jobTitle']?.toString() ?? 'Associate Professor';
    final department = facultyData?['department']?.toString() ?? 'M.Tech CSE';
    final employeeId =
        facultyData?['employeeId']?.toString() ?? widget.facultyId;
    final highestQualification =
        facultyData?['qualification']?.toString() ?? 'PHD';
    final dateOfJoining =
        facultyData?['dateOfJoining']?.toString() ?? '12/05/2010';
    final dateOfBirth = facultyData?['dateOfBirth']?.toString() ?? '02.05.1975';
    final emailId = facultyData?['email']?.toString() ?? 'nithya.cj@siram.co';
    final contactNo = facultyData?['contactNo']?.toString() ?? '7344507768';
    final address =
        facultyData?['address']?.toString() ?? '12 New Colony, XYZ city - 045';
    final profileImageUrl = facultyData?['profileImageUrl']?.toString();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Log out',
          ),
        ],
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
                          backgroundColor:
                              const Color(0xFFFF8C61).withOpacity(0.12),
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
                            color: const Color.fromARGB(255, 0, 0, 0),
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: screenWidth > 600 ? 16 : 12),
                        _buildGroupCard(
                          screenWidth: screenWidth,
                          items: [
                            MapEntry('Job Title', jobTitle),
                            MapEntry('Department', department),
                            MapEntry('Employee ID', employeeId),
                          ],
                        ),
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
                            color: const Color.fromARGB(255, 0, 0, 0),
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: screenWidth > 600 ? 16 : 12),
                        _buildGroupCard(
                          screenWidth: screenWidth,
                          items: [
                            MapEntry(
                                'Highest Qualification', highestQualification),
                            MapEntry('Date of Joining', dateOfJoining),
                            MapEntry('Date of Birth', dateOfBirth),
                            MapEntry('E-mail ID', emailId),
                            MapEntry('Contact No', contactNo),
                            MapEntry('Address', address),
                          ],
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: screenWidth > 600 ? 32 : 24),

                  // Logout Button
                  // Padding(
                  //   padding: EdgeInsets.symmetric(
                  //     horizontal: screenWidth > 600 ? 24.0 : 16.0,
                  //   ),
                  //   child: SizedBox(
                  //     width: double.infinity,
                  //     height: 48,
                  //     child: ElevatedButton.icon(
                  //       onPressed: _logout,
                  //       icon: const Icon(Icons.logout_rounded, color: Colors.white),
                  //       label: const Text(
                  //         'LOG OUT',
                  //         style: TextStyle(
                  //           fontWeight: FontWeight.bold,
                  //           fontSize: 14,
                  //           letterSpacing: 1.0,
                  //         ),
                  //       ),
                  //       style: ElevatedButton.styleFrom(
                  //         backgroundColor: Colors.red.shade600,
                  //         foregroundColor: Colors.white,
                  //         shape: RoundedRectangleBorder(
                  //           borderRadius: BorderRadius.circular(12),
                  //         ),
                  //         elevation: 2,
                  //       ),
                  //     ),
                  //   ),
                  // ),

                  const SizedBox(height: 140),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard({
    required List<MapEntry<String, String>> items,
    required double screenWidth,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF36454F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: List.generate(items.length, (index) {
            final item = items[index];
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth > 600 ? 20 : 16,
                    vertical: screenWidth > 600 ? 18 : 14,
                  ),
                  child: Row(
                    children: [
                      Text(
                        item.key,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: screenWidth > 600 ? 15 : 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.value,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: screenWidth > 600 ? 15 : 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < items.length - 1)
                  const Divider(
                    color: Colors.white12,
                    height: 1,
                    thickness: 1,
                    indent: 16,
                    endIndent: 16,
                  ),
              ],
            );
          }),
        ),
      ),
    );
  }
}
