import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';

class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({super.key});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  List<String> otpValues = List.filled(6, '');
  final FocusNode _focusNode = FocusNode();
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool isOtpSent = false;
  String? generatedOtp;
  final TextEditingController _emailController = TextEditingController();

  // Function to validate email format
  bool isValidEmail(String email) {
    RegExp emailRegExp = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    return emailRegExp.hasMatch(email);
  }

  // Function to generate OTP (for demo purposes)
  String generateOtp() {
    Random random = Random();
    return List.generate(6, (index) => random.nextInt(10).toString()).join();
  }

  // Function to send OTP (in a real app, you would send it via an API)
  void sendOtp() {
    if (isValidEmail(_emailController.text)) {
      setState(() {
        isOtpSent = true;
        generatedOtp = generateOtp(); // Generate a new OTP
      });
      print("OTP sent to: ${_emailController.text}");
      print("Generated OTP: $generatedOtp");
      // Here you would typically call an API to send the OTP to the email
    } else {
      // Show error message for invalid email format
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
    }
  }

  // Function to resend OTP
  void resendOtp() {
    if (isValidEmail(_emailController.text)) {
      setState(() {
        generatedOtp = generateOtp(); // Generate a new OTP
      });
      print("OTP resent to: ${_emailController.text}");
      print("New OTP: $generatedOtp");
      // You can also implement a resend logic with a delay or a counter
    } else {
      // Show error message for invalid email format
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid email address.')),
      );
    }
  }

  // Function to validate OTP
  void validateOtp() {
    String otp = otpValues.join();
    if (otp == generatedOtp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP Verified!')),
      );
      // Proceed to next screen or action after OTP verification
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid OTP! Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBFB),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Image.asset(
                  'assets/otp.png', // Use your own asset path
                  height: 120,
                ),
                const SizedBox(height: 30),

                // Title
                const Text(
                  'OTP Verification',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),

                // Instruction text
                Text(
                  isOtpSent
                      ? 'Enter the 6-digit OTP we sent to your email'
                      : 'Enter your email to receive an OTP',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),

                // Email input or OTP input based on `isOtpSent`
                if (!isOtpSent)
                  Column(
                    children: [
                      TextField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 25),
                      ElevatedButton(
                        onPressed: sendOtp,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF805E),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: const Text(
                          'Send OTP',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                if (isOtpSent) ...[
                  const SizedBox(height: 25),

                  // OTP input boxes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 45,
                        child: TextField(
                          focusNode: _focusNodes[index],
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 5) {
                              _focusNodes[index + 1].requestFocus();
                            }
                            setState(() {
                              otpValues[index] = value;
                            });
                          },
                          textAlign: TextAlign.center,
                          maxLength: 1,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            counterText: '',
                            filled: true,
                            fillColor: Color(0xFFEAEAEA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.all(Radius.circular(8)),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 30),

                  // Confirm button
                  ElevatedButton(
                    onPressed: validateOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF805E),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Confirm OTP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Resend OTP option
                if (isOtpSent)
                  GestureDetector(
                    onTap: resendOtp,
                    child: const Text(
                      'Resend OTP',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
