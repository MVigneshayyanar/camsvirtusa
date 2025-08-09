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
          automaticallyImplyLeading: false, // Remove back arrow
          title: const Text("ADMIN DASHBOARD", style: TextStyle(color: Colors.white, fontSize: 20)),
          centerTitle: true,
        ),
      ),
      body: Column(
        children: [
          _buildProfileSection(),
          const SizedBox(height: 10), // Reduced height
          _buildDashboardGrid(context),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildProfileSection() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFFFFD700),
            child: ClipOval(
              child: Image.asset(
                "assets/account.png",
                width: 60,
                height: 60,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            "Hello! SHINY M",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
  Widget _buildDashboardGrid(BuildContext context) {
    return Expanded(
      child: GridView.count(
        padding: const EdgeInsets.all(20.0),
        crossAxisCount: 2,
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
          ),
          _buildDashboardCard(
            context,
            label: "DEPARTMENTS",
            imagePath: "assets/department_ad.png",
            route: AppRoutes.departmentControl,
          ),
          _buildDashboardCard(
            context,
            label: "TIME TABLE",
            imagePath: "assets/timetable_ad.png",
            route: "/timetable",
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required String label,
        required String imagePath,
        required String route,
      }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Color(0xFF36454F),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateTo(context, route),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              imagePath,
              width: 70, // Increased size
              height: 70, // Increased size
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
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
    );
  }
}