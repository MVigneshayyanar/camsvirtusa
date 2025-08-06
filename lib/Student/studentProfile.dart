import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
      // Step 1: Fetch student data
      final studentDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .get();

      if (!studentDoc.exists) throw Exception("Student not found");

      studentData = studentDoc.data();

      // Step 2: Search for mentor who has this student in their mentees list
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

  @override
  Widget build(BuildContext context) {
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
        backgroundColor: _orange,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Center(
          child: Text('STUDENT PROFILE', style: TextStyle(color: Colors.white)),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () {},
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              color: _orange,
              padding: const EdgeInsets.only(bottom: 30),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: AssetImage('assets/default_profile.png'),
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      text: 'Hello! ',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      children: [
                        TextSpan(
                          text: name.toUpperCase(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _cardGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 80),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        decoration: const BoxDecoration(
          color: _lightGrayBg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            InkWell(
              onTap: _goToSearch,
              child: Image.asset('assets/search.png', width: 28, height: 28),
            ),
            InkWell(
              onTap: _goToDashboard,
              child: Image.asset('assets/homeLogo.png', width: 32, height: 32),
            ),
            InkWell(
              onTap: () {}, // already on profile
              child: Image.asset('assets/account.png', width: 28, height: 28),
            ),
          ],
        ),
      ),
    );
  }
}
