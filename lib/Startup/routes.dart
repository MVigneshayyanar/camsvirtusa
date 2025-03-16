import 'package:flutter/material.dart';
import '../Authentication/studentLogin.dart';
import '../Authentication/facultyLogin.dart';
import '../Authentication/otpVerification.dart';
import '../Startup/splashScreen.dart';
import '../Startup/roleSelection.dart';
import '../Student/studentDashboard.dart';
import '../Faculty/facultyDashboard.dart';

class AppRoutes {
  static const String splash = '/';
  static const String roleSelection = '/roleSelection';
  static const String studentLogin = '/studentLogin';
  static const String facultyLogin = '/facultyLogin';
  static const String otpVerification = '/otpVerification';
  static const String studentDashboard = '/studentDashboard';
  static const String facultyDashboard = '/facultyDashboard';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return _fadeRoute( SplashScreen(), settings);
      case roleSelection:
        return _fadeRoute(const RoleSelectionScreen(), settings);
      case studentLogin:
        return _fadeRoute(const StudentLoginScreen(), settings);
      case facultyLogin:
        return _fadeRoute(const FacultyLoginScreen(), settings);
      case otpVerification:
        return _fadeRoute(const OTPVerificationScreen(), settings);
      case studentDashboard:
        return _fadeRoute(const StudentDashboard(), settings);
      case facultyDashboard:
        return _fadeRoute(const FacultyDashboard(), settings);
      default:
        return _fadeRoute( SplashScreen(), settings);
    }
  }

  // Function for fade transition effect
  static PageRouteBuilder _fadeRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }
}
