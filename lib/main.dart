import 'package:flutter/material.dart';
import 'Startup/routes.dart';

void main() {
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
      routes: AppRoutes.getRoutes(),  // ✅ Call getRoutes() instead of using AppRoutes.routes
    );
  }
}
