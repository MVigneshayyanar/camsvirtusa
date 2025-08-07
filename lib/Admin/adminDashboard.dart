import 'package:flutter/material.dart';
import 'package:camsvirtusa/Startup/routes.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({Key? key}) : super(key: key);

  void _navigateTo(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: const Color(0xFFFF8145),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {},
          ),
          title: const Text("ADMIN DASHBOARD", style: TextStyle(color: Colors.white)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
      ),

      body: ListView(
        children: [
          _buildDashboardCard(
            context,
            label: "FACULTIES",
            imagePath: "assets/staff_ad.png",
            route: AppRoutes.facultyControl,
          ),
          _buildDashboardCard(
            context,
            label: "STUDENTS",
            imagePath: "assets/student_ad.png",
            route: AppRoutes.studentControl,
            grey: true,
          ),
          _buildDashboardCard(
            context,
            label: "DEPARTMENTS",
            imagePath: "assets/department_ad.png",
            route: "/department",
            grey: true,
          ),
          _buildDashboardCard(
            context,
            label: "TIME TABLE SCHEDULING",
            imagePath: "assets/timetable_ad.png",
            route: "/timetable",
            grey: true,
          ),
        ],
      ),

      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: Color(0xFFE5E5E5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Image.asset("assets/search.png", height: 26),
              onPressed: () {},
            ),
            IconButton(
              icon: Image.asset("assets/homeLogo.png", height: 32),
              onPressed: () {},
            ),
            IconButton(
              icon: Image.asset("assets/account.png", height: 26),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required String label,
        required String imagePath,
        required String route,
        bool grey = false,
      }) {
    return Container(
      color: grey ? const Color(0xFFE0E0E0) : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _navigateTo(context, route),
        child: Row(
          children: [
            ClipOval(
              child: Image.asset(
                imagePath,
                width: 70,
                height: 70,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
