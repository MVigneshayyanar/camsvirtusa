import 'package:flutter/material.dart';

// class AttendancePage extends StatefulWidget {
//   final String studentName;
//   final List<String> semesters;
//
//   AttendancePage({required this.studentName});
//
//   @override
//   _AttendancePageState createState() => _AttendancePageState();
// }

class AttendancePage extends StatefulWidget {
  final String studentId;

  const AttendancePage({Key? key, required this.studentId}) : super(key: key);

  @override
  _AttendancePageState createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  String selectedSemester = '1st SEM'; // Initialize the selectedSemester

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 700),
      vsync: this,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget buildProgressBar(double percentage, Color color) {
    return ClipPath(
      clipper: CustomClipPath(),
      child: Container(
        width: percentage * 2.4, // Adjust width according to percentage
        height: 20,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.horizontal(left: Radius.circular(30), right: Radius.circular(30)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFFF7A52),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
              ),
              padding: EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(Icons.menu, color: Colors.white),
                  Text(
                    'ATTENDANCE',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  Stack(
                    alignment: Alignment.topRight,
                    children: [
                      Icon(Icons.notifications, color: Colors.white),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.transparent,
                    child: ClipOval(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFFFFD085), Color(0xFFFFB86C)],
                          ),
                        ),
                        // child: Center(
                        //   child: Text(
                        //     widget.studentName[0], // Display initials
                        //     style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                        //   ),
                        // ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                buildProgressBar(0.86, Color(0xFF2ECC71)),
                                SizedBox(width: 10),
                                Text('86%'),
                              ],
                            ),
                            Row(
                              children: [
                                buildProgressBar(0.10, Color(0xFF1E90FF)),
                                SizedBox(width: 10),
                                Text('10%'),
                              ],
                            ),
                            Row(
                              children: [
                                buildProgressBar(0.04, Color(0xFFE74C3C)),
                                SizedBox(width: 10),
                                Text('4%'),
                              ],
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [Icon(Icons.arrow_circle_up, color: Color(0xFF2ECC71)), Text("PRESENT")]),
                              Row(children: [Icon(Icons.arrow_circle_up, color: Color(0xFF1E90FF)), Text("ON-DUTY")]),
                              Row(children: [Icon(Icons.arrow_circle_up, color: Color(0xFFE74C3C)), Text("ABSENT")]),
                            ],
                          ),
                        ),
                        // Text(
                        //   widget.studentName.toUpperCase(),
                        //   style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        // ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Text("★ Semester", style: TextStyle(color: Colors.red)),
                  SizedBox(width: 10),
                  // DropdownButton<String>(
                  //   value: selectedSemester,
                  //   items: widget.semesters.map((String value) {
                  //     return DropdownMenuItem<String>(
                  //       value: value,
                  //       child: Container(
                  //         decoration: BoxDecoration(
                  //             color: Colors.grey[300],
                  //             borderRadius: BorderRadius.circular(8)
                  //         ),
                  //         padding: EdgeInsets.all(10),
                  //         child: Text(value),
                  //       ),
                  //     );
                  //   }).toList(),
                  //   onChanged: (String? newValue) {
                  //     setState(() {
                  //       selectedSemester = newValue!;
                  //     });
                  //   },
                  // ),
                ],
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF7A52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: EdgeInsets.symmetric(horizontal: 60, vertical: 15),
              ),
              child: Text('Get Attendance'),
            ),
            Text(
              'DOWNLOAD',
              style: TextStyle(color: Color(0xFF2ECC71)),
            ),
            SizedBox(height: 30),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: BottomNavigationBar(
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.search), label: ""),
            BottomNavigationBarItem(
                icon: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFFFF7A52),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.home, color: Colors.white),
                ),
                label: ""
            ),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: ""),
          ],
          currentIndex: 1,
          selectedItemColor: Colors.black,
          unselectedItemColor: Colors.grey,
        ),
      ),
    );
  }
}

class CustomClipPath extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(size.width - 30, 0);
    path.lineTo(size.width, size.height / 2);
    path.lineTo(size.width - 30, size.height);
    path.lineTo(0, size.height);
    path.lineTo(0, 0);
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}