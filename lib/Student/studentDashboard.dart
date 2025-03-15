import 'package:flutter/material.dart';

class StudentDashboard extends StatelessWidget {
  const StudentDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Student Dashboard"), backgroundColor: Colors.teal),
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
                  Icon(Icons.person, size: 40, color: Colors.teal),
                  const SizedBox(width: 10),
                  const Text("Welcome, Student!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                  _dashboardButton(Icons.schedule, "Attendance"),
                  _dashboardButton(Icons.assignment, "Assignments"),
                  _dashboardButton(Icons.notifications, "Notifications"),
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
