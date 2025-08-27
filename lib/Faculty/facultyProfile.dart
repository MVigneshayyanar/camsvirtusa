import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  void _goToDashboard() {
    Navigator.pop(context);
  }

  Widget _buildBottomNavigationBar() {
    final mediaQuery = MediaQuery.of(context);
    final double bottomSafeArea = mediaQuery.padding.bottom;
    final double screenWidth = mediaQuery.size.width;

    return Container(
      height: 70 + bottomSafeArea,
      decoration: const BoxDecoration(
        color: Color(0xFFE5E5E5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSafeArea),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Image.asset(
                "assets/search.png",
                height: screenWidth > 600 ? 30 : 26,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.search,
                    color: const Color(0xFF6B7280),
                    size: screenWidth > 600 ? 28 : 24,
                  );
                },
              ),
              onPressed: _goToSearch,
            ),
            IconButton(
              icon: Image.asset(
                "assets/homeLogo.png",
                height: screenWidth > 600 ? 36 : 32,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.home_outlined,
                    color: const Color(0xFF6B7280),
                    size: screenWidth > 600 ? 32 : 28,
                  );
                },
              ),
              onPressed: _goToDashboard,
            ),
            IconButton(
              icon: Image.asset(
                "assets/account.png",
                height: screenWidth > 600 ? 30 : 26,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.person,
                    color: const Color(0xFFFF7F50),
                    size: screenWidth > 600 ? 28 : 24,
                  );
                },
              ),
              onPressed: () {
                // Already on profile, do nothing or refresh
                _fetchFacultyData();
              },
            ),
          ],
        ),
      ),
    );
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
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth > 600 ? 25 : 25,
              fontWeight: FontWeight.w500,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
        bottomNavigationBar: _buildBottomNavigationBar(),
      );
    }

    // Extract data from facultyData or use defaults
    final employeeName = facultyData?['name']?.toString() ?? 'Unknown Faculty';
    final academicYear = facultyData?['academicYear']?.toString() ?? 'Academic year : 2024-2025 / Even SEM';
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
        backgroundColor: const Color(0xFFFF7F50),
        title: Text(
          'FACULTY PROFILE',
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth > 600 ? 25 : 25,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Academic Year Banner
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF7F50),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  academicYear,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: screenWidth > 600 ? 16 : 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

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
                          backgroundColor: const Color(0xFFFF7F50),
                          backgroundImage: profileImageUrl != null
                              ? NetworkImage(profileImageUrl)
                              : const AssetImage('assets/account.png') as ImageProvider,
                          onBackgroundImageError: (exception, stackTrace) {
                            // Handle image loading errors
                          },
                          child: profileImageUrl == null && facultyData?['profileImage'] == null
                              ? Icon(
                            Icons.person,
                            size: screenWidth > 600 ? 40 : 35,
                            color: Colors.white,
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

      // Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNavigationBar(),
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