import 'package:flutter/material.dart';
import '../Startup/routes.dart';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key});

  @override
  _OTPVerificationScreenState createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final TextEditingController userIdController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF76C7C0), // Light teal background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Title
              const Text(
                "OTP VERIFICATION",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // User ID Field
              TextField(
                controller: userIdController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Enter User ID",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Send OTP Button
              ElevatedButton(
                onPressed: () {
                  // Logic to send OTP
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A7F77), // Dark teal
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Send OTP", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 20),

              // OTP Input Field
              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: "Enter OTP",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Verify OTP Button
              ElevatedButton(
                onPressed: () {
                  // Logic to verify OTP
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2A7F77), // Dark teal
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text("Verify OTP", style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 30),

              // Back Button (Positioned at Bottom)
              Align(
                alignment: Alignment.bottomCenter,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF2A7F77)),
                  label: const Text(
                    "Back",
                    style: TextStyle(fontSize: 16, color: Color(0xFF2A7F77)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
