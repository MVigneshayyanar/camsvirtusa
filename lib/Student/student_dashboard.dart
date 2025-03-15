import 'package:flutter/material.dart';

class StudentDashboardPage extends StatelessWidget {
  const StudentDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        title: const Text("STUDENT DASHBOARD"),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          children: const [
            DrawerHeader(
              decoration: BoxDecoration(color: Colors.teal),
              child: Text("Menu", style: TextStyle(color: Colors.white, fontSize: 20)),
            ),
            ListTile(leading: Icon(Icons.person), title: Text("Profile")),
            ListTile(leading: Icon(Icons.logout), title: Text("Logout")),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundImage: NetworkImage('https://via.placeholder.com/150'),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text("Welcome BALAJI R...!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildAttendanceBar(96, 4),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                children: [
                  _buildDashboardItem(Icons.person, "VIEW PROFILE"),
                  _buildDashboardItem(Icons.calendar_today, "CHECK ATTENDANCE"),
                  _buildDashboardItem(Icons.article, "ON DUTY FORM"),
                  _buildDashboardItem(Icons.request_page, "LEAVE FORM"),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceBar(int present, int absent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Attendance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              flex: present,
              child: Container(height: 10, color: Colors.green),
            ),
            Expanded(
              flex: absent,
              child: Container(height: 10, color: Colors.red),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Present: $present%", style: TextStyle(color: Colors.green, fontSize: 14)),
            Text("Absent: $absent%", style: TextStyle(color: Colors.red, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildDashboardItem(IconData icon, String title) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.teal.shade300,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(height: 10),
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
