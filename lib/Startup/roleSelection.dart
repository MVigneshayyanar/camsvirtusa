import 'package:flutter/material.dart';
import '../Startup/routes.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7886C7), // Light teal
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            crossAxisAlignment: CrossAxisAlignment.center, // Center horizontally
            children: [
              Image.asset(
                "assets/role_top.png", // Add your image here
                height: 150,
              ),
              const SizedBox(height: 20),
              const Text(
                "CHOOSE YOUR ROLE",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFFFFFFF), // Custom color
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),
              RoleButton(
                icon: Icons.school,
                text: "STUDENT",
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.studentLogin);
                },
              ),
              const SizedBox(height: 20),
              RoleButton(
                icon: Icons.person, // Faculty icon
                text: "FACULTY",
                onTap: () {
                  Navigator.pushNamed(context, AppRoutes.facultyLogin);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RoleButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const RoleButton({super.key, required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF2D336B), // Dark teal
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 5,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 40),
            const SizedBox(height: 10),
            Text(
              text.toUpperCase(),
              style: const TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
