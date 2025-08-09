import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Startup/routes.dart';

class FacultyLoginScreen extends StatefulWidget {
  const FacultyLoginScreen({super.key});

  @override
  _FacultyLoginScreenState createState() => _FacultyLoginScreenState();
}

class _FacultyLoginScreenState extends State<FacultyLoginScreen> {
  final TextEditingController _facultyIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _maybeAutoRedirect();
  }

  /// ✅ If already logged in, skip this screen
  Future<void> _maybeAutoRedirect() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    final role = prefs.getString('role');
    final facultyId = prefs.getString('facultyId');

    if (isLoggedIn && facultyId != null) {
      if (!mounted) return;
      if (role == 'faculty') {
        Navigator.pushReplacementNamed(context, AppRoutes.facultyDashboard, arguments: facultyId);
      } else if (role == 'admin') {
        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard, arguments: facultyId);
      }
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String enteredId = _facultyIdController.text.trim();
    final String password = _passwordController.text.trim();

    try {
      // ==== 1️⃣ Check FACULTY path ====
      final DocumentSnapshot facultyDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('faculties')
          .collection('all_faculties')
          .doc(enteredId)
          .get();

      if (facultyDoc.exists) {
        final data = facultyDoc.data() as Map<String, dynamic>;
        if (data['password'] == password) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('role', 'faculty');
          await prefs.setString('facultyId', enteredId);

          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            AppRoutes.facultyDashboard,
            arguments: enteredId,
          );
          return;
        } else {
          setState(() => _errorMessage = "Incorrect password.");
          return;
        }
      }

      // ==== 2️⃣ Check ADMIN path ====
      final DocumentSnapshot adminDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('admins')
          .collection('all_admins')
          .doc(enteredId)
          .get();

      if (adminDoc.exists) {
        final data = adminDoc.data() as Map<String, dynamic>;
        if (data['password'] == password) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('role', 'admin');
          await prefs.setString('facultyId', enteredId);

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard, arguments: enteredId);
          return;
        } else {
          setState(() => _errorMessage = "Incorrect password.");
          return;
        }
      }

      setState(() => _errorMessage = "ID not found.");

    } catch (e) {
      setState(() => _errorMessage = "Login failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/faculty.png", height: 150),
                const SizedBox(height: 30),
                const Text(
                  "FACULTY / ADMIN LOGIN",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: _facultyIdController,
                  decoration: InputDecoration(
                    hintText: "Faculty/Admin ID",
                    filled: true,
                    fillColor: const Color(0xFFE5E5E5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: "Password",
                    filled: true,
                    fillColor: const Color(0xFFE5E5E5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.black54,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.otpVerification),
                    child: const Text("Login via OTP?", style: TextStyle(color: Colors.black)),
                  ),
                ),
                const SizedBox(height: 10),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                  onPressed: _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8C61),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 80),
                  ),
                  child: const Text(
                    "Log in",
                    style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.studentLogin),
                  child: const Text.rich(
                    TextSpan(
                      text: "Are you a student? ",
                      style: TextStyle(color: Colors.black),
                      children: [
                        TextSpan(
                          text: "Click here",
                          style: TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                        ),
                      ],
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
