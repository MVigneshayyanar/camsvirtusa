import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Authentication/studentLogin.dart';
import '../Authentication/facultyLogin.dart';
import '../Authentication/otpVerification.dart';
import '../Startup/splashScreen.dart';
import '../Startup/roleSelection.dart';
import '../Student/studentDashboard.dart';
import '../Faculty/facultyDashboard.dart';
import '../Admin/adminDashboard.dart';
import '../Admin/studentControl.dart';
import '../Admin/facultyControl.dart';
import '../Admin/departmentControl.dart';
import '../Admin/classStudent.dart';

class AppRoutes {
  static const String splash = '/';
  static const String roleSelection = '/roleSelection';
  static const String studentLogin = '/studentLogin';
  static const String facultyLogin = '/facultyLogin';
  static const String otpVerification = '/otpVerification';
  static const String studentDashboard = '/studentDashboard';
  static const String facultyDashboard = '/facultyDashboard';
  static const String adminDashboard = '/adminDashboard';
  static const String studentControl = '/studentControl';
  static const String facultyControl = '/facultyControl';
  static const String departmentControl = '/departmentControl';
  static const String classStudents = '/classStudents';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _animatedRoute(SplashWrapper(), settings);

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
          return _noBackRoute(StudentDashboard(studentId: studentId), settings);
        } else {
          return _errorRoute("Invalid or Missing Student ID", settings);
        }

      case facultyDashboard:
        final facultyId = settings.arguments as String?;
        if (facultyId != null && facultyId.isNotEmpty) {
          return _noBackRoute(FacultyDashboard(facultyId: facultyId), settings);
        } else {
          return _errorRoute("Invalid or Missing Faculty ID", settings);
        }

      case adminDashboard:
        return _noBackRoute(const AdminDashboard(), settings);

      case studentControl:
        return _animatedRoute(const StudentControlPage(), settings);

      case facultyControl:
        return _animatedRoute(const FacultyOverviewPage(), settings);

      case departmentControl:
        return _animatedRoute(const DepartmentControlPage(), settings);

      default:
        return _errorRoute("Page Not Found", settings);
    }
  }

  // Wrapper for SplashScreen that decides initial route
  static Widget SplashWrapper() {
    return FutureBuilder<bool>(
      future: _checkLogin(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SplashScreen();
        }
        if (snapshot.data == true) {
          return const RoleSelectionScreen(); // or directly to dashboard if you store role
        }
        return const RoleSelectionScreen();
      },
    );
  }

  static Future<bool> _checkLogin() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool("isLoggedIn") ?? false;
  }

  static Future<void> setLoginState(bool loggedIn) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool("isLoggedIn", loggedIn);
  }

  // Slide + Fade transition
  static PageRouteBuilder _animatedRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final fadeTween =
        Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation.drive(fadeTween), child: child),
        );
      },
    );
  }

  // Route where back button exits app instead of going to login
  static PageRouteBuilder _noBackRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => WillPopScope(
        onWillPop: () async => false,
        child: page,
      ),
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final fadeTween =
        Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child: FadeTransition(opacity: animation.drive(fadeTween), child: child),
        );
      },
    );
  }

  // Error page
  static PageRouteBuilder _errorRoute(String message, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => Scaffold(
        backgroundColor: const Color(0xFF7886C7),
        body: Center(
          child: Text(
            message,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
