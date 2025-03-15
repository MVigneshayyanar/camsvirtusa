import 'package:flutter/material.dart';
import '../Authentication/loginPage.dart';
import '../Authentication/otpVerification.dart';
import '../Startup/splashScreen.dart';
import '../Startup/roleSelection.dart';
import '../Student/studentDashboard.dart';
import '../Faculty/facultyDashboard.dart';

class AppRoutes {
  static const String splash = '/';
  static const String roleSelection = '/roleSelection';
  static const String studentLogin = '/studentLogin';
  static const String teacherLogin = '/teacherLogin';
  static const String otpVerification = '/otpVerification';
  static const String studentDashboard = '/studentDashboard';
  static const String teacherDashboard = '/teacherDashboard';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splash: (context) => SplashScreen(),
      roleSelection: (context) => RoleSelectionScreen(),
      studentLogin: (context) => StudentLoginScreen(),
      otpVerification: (context) => OTPVerificationScreen(),
      studentDashboard: (context) => StudentDashboard(),
      teacherDashboard: (context) => TeacherDashboard(),
    };
  }
}
