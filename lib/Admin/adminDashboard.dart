import 'package:flutter/material.dart';
import 'package:camsvirtusa/Startup/routes.dart'; // Import routes file

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  void _navigateTo(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2D336B),
        title: const Text(
          "ADMIN DASHBOARD",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            onPressed: () {
              // Handle Home button action
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF7886C7), // Background color
        child: ListView(
          padding: const EdgeInsets.all(15),
          children: [
            _buildDashboardButton(context, "STUDENT", "assets/student_ad.png", AppRoutes.studentControl),
            _buildDashboardButton(context, "STAFF", "assets/staff_ad.png", "/staff"),
            _buildDashboardButton(context, "BATCH OVERVIEW", "assets/batch_ad.png", "/batch"),
            _buildDashboardButton(context, "DEPARTMENT OVERVIEW", "assets/department_ad.png", "/department"),
            _buildDashboardButton(context, "TIMETABLE SCHEDULING", "assets/timetable_ad.png", "/timetable"),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardButton(BuildContext context, String label, String imagePath, String route) {
    return GestureDetector(
      onTap: () => _navigateTo(context, route),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.grey[300], // Card background
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(30),
              child: Image.asset(imagePath, height: 50, width: 50, fit: BoxFit.cover),
            ),
          ],
        ),
      ),
    );
  }
}
