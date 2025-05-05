import 'package:flutter/material.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String? _selectedSemester;

  final List<String> semesters = [
    "I SEM", "II SEM", "III SEM", "IV SEM",
    "V SEM", "VI SEM", "VII SEM", "VIII SEM"
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ATTENDANCE"),
        backgroundColor: Colors.redAccent,
        actions: const [
          Icon(Icons.notifications, color: Colors.white),
        ],
        leading: const Icon(Icons.menu, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage('assets/profile.png'), // Replace with your image
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("BALAJI R", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Row(
                      children: [
                        const Text("96%", style: TextStyle(color: Colors.green, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          width: 100,
                          height: 10,
                          color: Colors.green,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Text("4%", style: TextStyle(color: Colors.red, fontSize: 14)),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 10,
                          color: Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Row(
                      children: [
                        Icon(Icons.arrow_drop_up, color: Colors.green),
                        Text("PRESENT", style: TextStyle(fontSize: 12)),
                        SizedBox(width: 10),
                        Icon(Icons.arrow_drop_up, color: Colors.red),
                        Text("ABSENT", style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: const [
                Text(
                  "*Semester",
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [BoxShadow(color: Colors.grey, blurRadius: 2)],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  hint: const Text("Select Semester"),
                  value: _selectedSemester,
                  items: semesters.map((sem) {
                    return DropdownMenuItem(value: sem, child: Text(sem));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSemester = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: implement get attendance logic
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text("Get Attendence", style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // TODO: implement download
              },
              child: const Text("DOWNLOAD", style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.apps), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: ""),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: ""),
        ],
      ),
    );
  }
}
