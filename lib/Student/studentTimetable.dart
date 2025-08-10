import 'package:camsvirtusa/Student/studentProfile.dart';
import 'package:flutter/material.dart';
import 'studentDashboard.dart';

class TimeTablePage extends StatelessWidget {

  final String studentId;

  const TimeTablePage({Key? key, required this.studentId}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Color(0xFFFF7F50), // Orange color
        title: Text(
          'TIME TABLE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 25,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Current Semester Section
          Container(
            margin: EdgeInsets.only(left: 16, right: 16, top: 45, bottom: 16),
            padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            decoration: BoxDecoration(
              color: Color(0xFF36454F), // Dark gray
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'CURRENT SEMESTER : V',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // Time Table Container
          Container(
            margin: EdgeInsets.symmetric(horizontal: 10, vertical: 40),
            padding: EdgeInsets.all(0),
            decoration: BoxDecoration(// Light gray background
              border: Border.all(color: Color(0xFF36454F), width:3),
            ),
            child: SingleChildScrollView(
              child: _buildTimeTableImage(),
            ),
          ),

          SizedBox(height: 100),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildTimeTableImage() {
    return Center(
      child: InteractiveViewer(
        child: Image.asset(
          'assets/MTechVtt.png', // Replace with your time table image path
          fit: BoxFit.fitWidth,
          width: double.infinity,
        ),
      ),
    );
  }

  void _goToDashboard(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDashboard(studentId: studentId),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double bottomSafeArea = mediaQuery.padding.bottom;
    final double screenWidth = mediaQuery.size.width;

    return Container(
      height: 70 + bottomSafeArea,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSafeArea),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Image.asset(
                "assets/search.png",
                height: screenWidth > 600 ? 30 : 26,
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: Image.asset(
                "assets/homeLogo.png",
                height: screenWidth > 600 ? 36 : 32,
              ),
              onPressed: () => _goToDashboard(context),
            ),
            IconButton(
              icon: Image.asset(
                "assets/account.png",
                height: screenWidth > 600 ? 30 : 26,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentProfile(studentId: studentId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}