import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Authentication/loginScreen.dart';
import '../Startup/splashScreen.dart';
import '../Student/studentDashboard.dart';
import '../Faculty/facultyDashboard.dart';
import '../Student/studentMainScreen.dart';
import '../Faculty/facultyMainScreen.dart';
import '../Authentication/face_verification_screen.dart';
import '../Authentication/face_enrollment_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String studentLogin = '/studentLogin';
  static const String faceVerification = '/faceVerification';
  static const String faceEnrollment = '/faceEnrollment';
  static const String facultyLogin = '/facultyLogin';
  static const String login = '/login';
  static const String studentDashboard = '/studentDashboard';
  static const String facultyDashboard = '/facultyDashboard';
  static const String classStudents = '/classStudents';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _animatedRoute(SplashWrapper(), settings);

      case studentLogin:
        return _animatedRoute(
            const LoginScreen(initialRole: 'student'), settings);

      case login:
        final role = settings.arguments as String? ?? 'student';
        return _animatedRoute(LoginScreen(initialRole: role), settings);

      case faceVerification:
        final studentId = settings.arguments as String?;
        if (studentId != null && studentId.isNotEmpty) {
          return _animatedRoute(
              FaceVerificationScreen(studentId: studentId), settings);
        } else {
          return _errorRoute(
              "Invalid or Missing Student ID for Verification", settings);
        }

      case faceEnrollment:
        final enrollStudentId = settings.arguments as String?;
        if (enrollStudentId != null && enrollStudentId.isNotEmpty) {
          return _noBackRoute(
              FaceEnrollmentScreen(studentId: enrollStudentId), settings);
        } else {
          return _errorRoute(
              "Invalid or Missing Student ID for Enrollment", settings);
        }

      case facultyLogin:
        return _animatedRoute(
            const LoginScreen(initialRole: 'faculty'), settings);

      case studentDashboard:
        String? studentId;
        String? verificationTime;
        if (settings.arguments is Map) {
          final args = settings.arguments as Map;
          studentId = args['studentId'] as String?;
          verificationTime = args['verificationTime'] as String?;
        } else if (settings.arguments is String) {
          studentId = settings.arguments as String;
          verificationTime = DateTime.now().toIso8601String();
        }
        if (studentId != null && studentId.isNotEmpty) {
          return _noBackRoute(
              StudentMainScreen(
                  studentId: studentId, verificationTime: verificationTime),
              settings);
        }
        return _errorRoute(
            "Invalid or Missing Arguments for Dashboard", settings);

      case facultyDashboard:
        final facultyId = settings.arguments as String?;
        if (facultyId != null && facultyId.isNotEmpty) {
          return _noBackRoute(
              FacultyMainScreen(facultyId: facultyId), settings);
        } else {
          return _errorRoute("Invalid or Missing Faculty ID", settings);
        }

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
        // Always go to LoginScreen — it handles auto-redirect if already logged in
        return const LoginScreen();
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
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final fadeTween =
            Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child:
              FadeTransition(opacity: animation.drive(fadeTween), child: child),
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
        final tween =
            Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        final fadeTween =
            Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
        return SlideTransition(
          position: animation.drive(tween),
          child:
              FadeTransition(opacity: animation.drive(fadeTween), child: child),
        );
      },
    );
  }

  // Error page
  static PageRouteBuilder _errorRoute(String message, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (_, __, ___) => Scaffold(
        backgroundColor: Colors.white,
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
