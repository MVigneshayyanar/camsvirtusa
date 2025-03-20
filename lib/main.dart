import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'Startup/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensures Flutter is initialized
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Presenza',
      theme: ThemeData(primarySwatch: Colors.teal),
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute, // Use custom route transitions
    );
  }
}
