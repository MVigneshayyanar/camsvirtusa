import 'package:flutter/material.dart';
import '../Authentication/studentLogin.dart';
import '../Authentication/facultyLogin.dart';
import '../Authentication/otpVerification.dart';
import '../Startup/splashScreen.dart';
import '../Startup/roleSelection.dart';
import '../Student/studentDashboard.dart';
import '../Faculty/facultyDashboard.dart';
import '../Admin/adminDashboard.dart';
import '../Admin/studentControl.dart'; // Import Student Control Page
import '../Admin/addStudent.dart'; // Import Add Student Page
import '../Admin/viewStudent.dart'; // Import View Student Page

class AppRoutes {
  static const String splash = '/';
  static const String roleSelection = '/roleSelection';
  static const String studentLogin = '/studentLogin';
  static const String facultyLogin = '/facultyLogin';
  static const String otpVerification = '/otpVerification';
  static const String studentDashboard = '/studentDashboard';
  static const String facultyDashboard = '/facultyDashboard';
  static const String adminDashboard = '/adminDashboard';
  static const String studentControl = '/studentControl'; // Student Control Page
  static const String addStudent = '/addStudent'; // Add Student Page
  static const String viewStudent = '/viewStudent'; // View Student Page

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _animatedRoute(SplashScreen(), settings);

      case roleSelection:
        return _animatedRoute(const RoleSelectionScreen(), settings);

      case studentLogin:
        return _animatedRoute(const StudentLoginScreen(), settings);

      case facultyLogin:
        return _animatedRoute(const FacultyLoginScreen(), settings);

      case otpVerification:
        return _animatedRoute(const OTPVerificationScreen(), settings);

      case studentDashboard:
        final studentId = settings.arguments as String?;
        if (studentId != null && studentId.isNotEmpty) {
          return _animatedRoute(StudentDashboard(studentId: studentId), settings);
        } else {
          return _errorRoute("Invalid or Missing Student ID", settings);
        }

      case facultyDashboard:
        final facultyId = settings.arguments as String?;
        if (facultyId != null && facultyId.isNotEmpty) {
          return _animatedRoute(FacultyDashboard(facultyId: facultyId), settings);
        } else {
          return _errorRoute("Invalid or Missing Faculty ID", settings);
        }

      case adminDashboard:
        return _animatedRoute(const AdminDashboard(), settings);

      case studentControl:
        return _animatedRoute(StudentControlScreen(), settings);

      case addStudent:
        return _animatedRoute(AddStudentScreen(), settings);

      case viewStudent:
        return _animatedRoute(ViewStudentScreen(), settings);

      default:
        return _errorRoute("Page Not Found", settings);
    }
  }

  // Function for smooth transition effect (Slide + Fade)
  static PageRouteBuilder _animatedRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0); // Slide from right
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation.drive(fadeTween), child: child),
        );
      },
    );
  }

  // Function for handling invalid routes
  static PageRouteBuilder _errorRoute(String message, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
        backgroundColor: const Color(0xFF7886C7),
        body: Center(
          child: Text(
            message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ),
      ),
    );
  }
}
