import 'package:flutter/material.dart';

class StudentAttendancePage extends StatefulWidget {
  const StudentAttendancePage({super.key});

  @override
  State<StudentAttendancePage> createState() => _StudentAttendancePageState();
}

class _StudentAttendancePageState extends State<StudentAttendancePage> {
  String selectedSemester = 'I SEM';

  final List<String> semesters = [
    'I SEM',
    'II SEM',
    'III SEM',
    'IV SEM',
    'V SEM',
    'VI SEM',
    'VII SEM',
    'VIII SEM',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2D3A73),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Top AppBar Section
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFF2D3A73),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Icon(Icons.menu, color: Colors.white),
                    Text('ATTENDANCE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        )),
                    Icon(Icons.home, color: Colors.white),
                  ],
                ),
              ),

              // Profile and Attendance Info
              Container(
                padding: const EdgeInsets.all(16),
                color: const Color(0xFF2D3A73),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundImage: AssetImage('assets/profile.jpg'), // Replace with your image
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('BALAJI R',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                flex: 96,
                                child: Container(
                                  height: 20,
                                  color: Colors.green,
                                ),
                              ),
                              Expanded(
                                flex: 4,
                                child: Container(
                                  height: 20,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('96%', style: TextStyle(color: Colors.white)),
                              Text('4%', style: TextStyle(color: Colors.white)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: const [
                              Icon(Icons.arrow_drop_up, color: Colors.green),
                              Text('PRESENT', style: TextStyle(color: Colors.white)),
                              SizedBox(width: 10),
                              Icon(Icons.arrow_drop_down, color: Colors.red),
                              Text('ABSENT', style: TextStyle(color: Colors.white)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Semester Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '*Semester',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: Colors.grey[200],
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedSemester,
                          items: semesters
                              .map((sem) => DropdownMenuItem(value: sem, child: Text(sem)))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSemester = value!;
                            });
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2D3A73),
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
                        ),
                        onPressed: () {
                          // TODO: Load attendance for selected semester
                        },
                        child: const Text('GET ATTENDANCE'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          const Icon(Icons.download, color: Colors.green, size: 40),
                          const Text('DOWNLOAD', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
