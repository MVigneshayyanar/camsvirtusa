import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  DashboardCard({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 10),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Color(0xFF2A7F77),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 30),
            SizedBox(width: 15),
            Expanded(
              child: Text(title, style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}
