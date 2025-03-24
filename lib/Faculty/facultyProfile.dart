import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FacultyProfile extends StatefulWidget {
  final String facultyId;

  const FacultyProfile({super.key, required this.facultyId});

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
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('faculties') // ✅ Corrected Collection Name
          .doc(widget.facultyId)
          .get();

      if (doc.exists) {
        setState(() {
          facultyData = doc.data() as Map<String, dynamic>? ?? {};
          _isLoading = false;
        });
      } else {
        setState(() {
          facultyData = {};
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildInfoRow(String label, String? value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.white : Colors.white70,
            ),
          ),
          Text(
            value ?? "N/A",
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1F2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1F2E),
        elevation: 0,
        title: const Text("FACULTY PROFILE"),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : facultyData != null
          ? SingleChildScrollView(
        child: Column(
          children: [
            // ✅ Profile Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF5C6BC0),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(50),
                ),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    backgroundImage: facultyData?['profileImage'] != null
                        ? NetworkImage(facultyData!['profileImage'])
                        : const AssetImage('assets/default_profile.png')
                    as ImageProvider,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Hello!",
                    style: TextStyle(
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                      color: Colors.white70,
                    ),
                  ),
                  Text(
                    facultyData?['name']?.toUpperCase() ?? "Faculty",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ✅ Faculty Details Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "FACULTY DETAILS",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF37474F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow("Designation", facultyData?['designation']),
                        _buildInfoRow("Department", facultyData?['department']),
                        _buildInfoRow("Faculty ID", facultyData?['facultyID']),
                        _buildInfoRow("Experience", facultyData?['experience']),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ✅ Contact Details Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "CONTACT DETAILS",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFF37474F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow("Email", facultyData?['email']),
                        _buildInfoRow("Phone", facultyData?['phone']),
                        _buildInfoRow("Office Room", facultyData?['officeRoom']),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ✅ Back Button
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      )
          : const Center(
        child: Text(
          "Faculty data not found!",
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
    );
  }
}
