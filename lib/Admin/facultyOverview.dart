import 'package:flutter/material.dart';
import 'viewFaculty.dart';
import 'addFaculty.dart';

class FacultyOverviewScreen extends StatelessWidget {
  const FacultyOverviewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("FACULTY CONTROL"),
        backgroundColor: const Color(0xFF2D336B),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFF76C7C0),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.person_search),
              label: const Text("VIEW FACULTY"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A7F77),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ViewFacultyScreen()),
                );
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text("ADD NEW FACULTY"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A7F77),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddFacultyScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
