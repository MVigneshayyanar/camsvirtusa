import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'facultyProfile.dart';
import 'MarkAttendance.dart';

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

  void _navigateToAdd() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkAttendance(facultyId: widget.facultyId),
      ),
    );
  }

  void _navigateTo(String page) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(page)),
          body: Center(child: Text('$page Page', style: const TextStyle(fontSize: 24))),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String label,
    required String assetPath,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              padding: const EdgeInsets.all(10),
              child: Image.asset(
                assetPath,
                width: 60,
                height: 60,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final name = facultyData?['name']?.toString().toUpperCase() ?? 'USER';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.deepOrangeAccent,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
          ),
          padding: const EdgeInsets.only(left: 16, top: 18, bottom: 18),
          alignment: Alignment.centerLeft,
          child: const Text(
            "FACULTY DASHBOARD",
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/profile.png'),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      children: [
                        const TextSpan(
                          text: 'Hello!\n',
                          style: TextStyle(fontSize: 18, color: Colors.black54, fontStyle: FontStyle.italic),
                        ),
                        TextSpan(
                          text: name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 25,
                crossAxisSpacing: 25,
                childAspectRatio: 1,
                children: [
                  _buildButton(
                    label: "Time Table",
                    assetPath: 'assets/time_table_icon.png',
                    onTap: () => _navigateTo('Time Table'),
                  ),
                  _buildButton(
                    label: "Mark Attendance",
                    assetPath: 'assets/mark_attendance_icon.png',
                    onTap: _navigateToAdd,
                  ),
                  _buildButton(
                    label: "My Mentees",
                    assetPath: 'assets/my_mentees_icon.png',
                    onTap: () => _navigateTo('Mentees'),
                  ),
                  _buildButton(
                    label: "Requests",
                    assetPath: 'assets/requests_icon.png',
                    onTap: () => _navigateTo('Requests'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Icon(Icons.search, size: 28, color: Colors.deepOrangeAccent),
            Icon(Icons.home, size: 28, color: Colors.black87),
            Icon(Icons.person_outline, size: 28, color: Colors.black87),
          ],
        ),
      ),
    );
  }
}
