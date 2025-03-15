import 'package:flutter/material.dart';
import 'routes.dart';

class RoleSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF76C7C0),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("CHOOSE YOUR ROLE", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          SizedBox(height: 20),
          RoleButton(icon: Icons.school, label: "STUDENT", route: AppRoutes.studentLogin),
          RoleButton(icon: Icons.person, label: "TEACHER", route: AppRoutes.teacherLogin),
        ],
      ),
    );
  }
}

class RoleButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  RoleButton({required this.icon, required this.label, required this.route});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF2A7F77),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      onPressed: () => Navigator.pushNamed(context, route),
      icon: Icon(icon, color: Colors.white),
      label: Text(label, style: TextStyle(fontSize: 18, color: Colors.white)),
    );
  }
}
