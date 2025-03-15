import 'package:flutter/material.dart';

class TeacherDashboard extends StatelessWidget {
  const TeacherDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Teacher Dashboard"), backgroundColor: Colors.teal),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.teal.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.school, size: 40, color: Colors.teal),
                  const SizedBox(width: 10),
                  const Text("Welcome, Teacher!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _dashboardButton(Icons.check_circle, "Mark Attendance"),
                  _dashboardButton(Icons.list, "View Reports"),
                  _dashboardButton(Icons.notifications, "Announcements"),
                  _dashboardButton(Icons.logout, "Logout", logout: true, context: context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dashboardButton(IconData icon, String label, {bool logout = false, BuildContext? context}) {
    return ElevatedButton(
      onPressed: () {
        if (logout && context != null) {
          Navigator.pop(context);
        }
      },
      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, padding: const EdgeInsets.all(16)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 40, color: Colors.white),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}
