import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'studentProfile.dart';
import 'studentAttendance.dart';

class StudentDashboard extends StatefulWidget {
  final String studentId;
  const StudentDashboard({Key? key, required this.studentId}) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  Map<String, dynamic>? studentData;
  Map<String, dynamic>? mentorData;
  bool _isLoading = true;

  static const Color _orange = Color(0xFFFF7F50);
  static const Color _darkGray = Color(0xFF2D336B);
  static const Color _lightGrayBg = Color(0xFFF0F0F0);

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      // 1) Fetch student
      final studentDoc = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.studentId)
          .get();
      if (!studentDoc.exists) throw Exception("No student found");
      studentData = studentDoc.data() as Map<String, dynamic>;

      // 2) Fetch mentor by facultyId field
      final mentorId = studentData!['mentorid'] as String;
      final mentorQuery = await FirebaseFirestore.instance
          .collection('faculties')
          .where('facultyId', isEqualTo: mentorId)
          .limit(1)
          .get();
      if (mentorQuery.docs.isNotEmpty)
        mentorData = mentorQuery.docs.first.data() as Map<String, dynamic>;
    } catch (e) {
      print("Error loading data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateTo(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            backgroundColor: _orange,
            title: Text(title),
          ),
          body: Center(child: Text("$title Page", style: TextStyle(fontSize: 24))),
        ),
      ),
    );
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentProfile(studentId: widget.studentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── DRAWER ─────────────────────────────────────────────────────────────
      drawer: Drawer(
        elevation: 0,
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.65,
            child: Container(
              color: _lightGrayBg,
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : Column(
                children: [
                  const SizedBox(height: 40),
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: _darkGray),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    studentData!['name'].toString().toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _drawerPill("Mentor : ${mentorData?['name'] ?? '—'}"),
                  _drawerPill("CGPA : ${studentData!['cgpa']}"),
                  _drawerPill("Current year : ${studentData!['year']}"),
                  Spacer(),
                  Divider(height: 1),
                  _drawerPill("Report", icon: Icons.info),
                  _drawerPill("Settings", icon: Icons.settings),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),

      // ── APP BAR ─────────────────────────────────────────────────────────────
      appBar: AppBar(
        backgroundColor: _orange,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text("STUDENT DASHBOARD", style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () => _navigateTo("Notifications"),
          )
        ],
      ),

      // ── BODY ────────────────────────────────────────────────────────────────
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Welcome ${studentData!['name']}...!",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Search Bar
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: _lightGrayBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey),
                    SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: "Search",
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Tiles row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // VIEW PROFILE → opens StudentProfile
                  _tile("VIEW PROFILE", 'assets/view_profile.png', _navigateToProfile),
                  _tile("CHECK ATTENDANCE", 'assets/check_attendance.png',
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const AttendancePage()),
                          ),),
                ],
              ),

              const SizedBox(height: 30),

              // News Panel
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 140,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _darkGray,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue, width: 2),
                    ),
                  ),
                  Positioned(
                    top: -12,
                    left: -12,
                    child:
                    Image.asset('assets/news.png', width: 60, height: 60),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // More news button
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _orange,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    padding: EdgeInsets.symmetric(horizontal: 50, vertical: 12),
                  ),
                  onPressed: () {},
                  child: Text("More news...", style: TextStyle(fontSize: 14)),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),

      // ── BOTTOM NAVIGATION ───────────────────────────────────────────────────
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
              child: Image.asset(
                'assets/search.png',
                width: 28,
                height: 28,
              ),
            ),

            // Home icon
            InkWell(
              onTap: (){},
              child: Image.asset(
                'assets/homeLogo.png',
                width: 32,
                height: 32,
              ),
            ),

            // Profile icon (active)
            InkWell(
              onTap: () =>_navigateToProfile, // already on profile
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

  Widget _drawerPill(String text, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(10),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.black54),
              SizedBox(width: 8),
            ],
            Text(text, style: TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _tile(String label, String assetPath, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 48) / 2,
        height: 120,
        decoration: BoxDecoration(
          color: _darkGray,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(assetPath, width: 56, height: 56),
            SizedBox(height: 8),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
