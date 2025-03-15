import 'package:flutter/material.dart';
import '../Startup/routes.dart';

class StudentLoginScreen extends StatelessWidget {
  const StudentLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset("assets/logo.png", height: 100), // Logo
            const SizedBox(height: 20),
            const Text(
              "Login",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.studentDashboard);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Login", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pushNamed(context, AppRoutes.otpVerification);
              },
              child: const Text("Login via OTP"),
            ),
          ],
        ),
      ),
    );
  }
}
