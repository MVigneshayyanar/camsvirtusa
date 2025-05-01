import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'studentDashboard.dart'; // adjust import path as needed

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
      // Load student record
      final doc = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .get();
      if (doc.exists) studentData = doc.data();

      // Load mentor record by facultyId == studentData['mentorid']
      final mentorId = studentData?['mentorid'] as String?;
      if (mentorId != null) {
        final q = await FirebaseFirestore.instance
            .collection('faculties')
            .where('facultyId', isEqualTo: mentorId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) mentorData = q.docs.first.data();
      }
    } catch (e) {
      print("Error fetching data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _infoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white70)),
          Text(value ?? '—',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
            title: Text("Search", style: TextStyle(color: Colors.white)),
          ),
          body: Center(child: Text("Search Page")),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _orange,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Center(
          child: Text('STUDENT PROFILE', style: TextStyle(color: Colors.white)),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          )
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            // Academic year strip
            Container(
              width: double.infinity,
              color: _orange,
              padding: EdgeInsets.symmetric(vertical: 8),
            ),

            // Header
            Container(
              width: double.infinity,
              color: _orange,
              padding: EdgeInsets.only(bottom: 30),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage:
                    AssetImage('assets/default_profile.png'),
                  ),
                  SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      text: 'Hello! ',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                      children: [
                        TextSpan(
                          text: studentData?['name']
                              ?.toString()
                              .toUpperCase() ??
                              '',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // STUDENT DETAILS
            SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('STUDENT DETAILS',
                    style: TextStyle(
                        color: _darkGray,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow(
                        'Academic Batch', studentData?['batch']?.toString()),
                    _infoRow(
                        'Current class', studentData?['year']?.toString()),
                    _infoRow('Student Status',
                        studentData?['status']?.toString()),
                  ],
                ),
              ),
            ),

            // PERSONAL DETAILS
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('PERSONAL DETAILS',
                    style: TextStyle(
                        color: _darkGray,
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow('Mentor Name', mentorData?['name']?.toString()),
                    _infoRow('University No',
                        studentData?['uno']?.toString()),
                    _infoRow('College ID',
                        studentData?['id']?.toString()),
                    _infoRow('Degree/Branch',
                        studentData?['dept']?.toString()),
                    _infoRow('Date of Birth',
                        studentData?['dob']?.toString()),
                    _infoRow('CGPA', studentData?['cgpa']?.toString()),
                  ],
                ),
              ),
            ),

            // spacer to avoid content behind nav bar
            SizedBox(height: 80),
          ],
        ),
      ),

      // ── CUSTOM ICON BOTTOM NAVIGATION ───────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(top: 12, bottom: 24),
        decoration: BoxDecoration(
          color: _lightGrayBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Search icon
            InkWell(
              onTap: _goToSearch,
              child: Image.asset(
                'assets/search.png',
                width: 28,
                height: 28,
              ),
            ),

            // Home icon
            InkWell(
              onTap: _goToDashboard,
              child: Image.asset(
                'assets/homeLogo.png',
                width: 32,
                height: 32,
              ),
            ),

            // Profile icon (active)
            InkWell(
              onTap: () {}, // already on profile
              child: Image.asset(
                'assets/account.png',
                width: 28,
                height: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
