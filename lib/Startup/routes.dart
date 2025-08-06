import 'package:flutter/material.dart';
import '../Authentication/studentLogin.dart';
import '../Authentication/facultyLogin.dart';
import '../Authentication/otpVerification.dart';
import '../Startup/splashScreen.dart';
import '../Startup/roleSelection.dart';
import '../Student/studentDashboard.dart';
import '../Faculty/facultyDashboard.dart';
import '../Admin/adminDashboard.dart';
import '../Admin/studentControl.dart';
import '../Admin/addStudent.dart';
import '../Admin/viewStudent.dart';
import '../Admin/facultyOverview.dart';
class AppRoutes {
  static const String splash = '/';
  static const String roleSelection = '/roleSelection';
  static const String studentLogin = '/studentLogin';
  static const String facultyLogin = '/facultyLogin';
  static const String otpVerification = '/otpVerification';
  static const String studentDashboard = '/StudentDashboard';
  static const String facultyDashboard = '/facultyDashboard';
  static const String adminDashboard = '/adminDashboard';
  static const String studentControl = '/studentControl';
  static const String addStudent = '/addStudent';
  static const String viewStudent = '/viewStudent';
  static const String facultyControl = '/facultyControl';


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
        return _animatedRoute(ViewStudent(), settings);

      case facultyControl:
        return _animatedRoute(FacultyOverviewScreen(), settings);

      default:
        return _errorRoute("Page Not Found", settings);
    }
  }

  // Slide + Fade transition animation
  static PageRouteBuilder _animatedRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, animation, __) => page,
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;

        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final fadeTween = Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));

        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation.drive(fadeTween), child: child),
        );
      },
    );
  }

  // Error page route
  static PageRouteBuilder _errorRoute(String message, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => Scaffold(
        backgroundColor: const Color(0xFF7886C7),
        body: Center(
          child: Text(
            message,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
