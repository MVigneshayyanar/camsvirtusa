import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'studentDashboard.dart';
import 'studentProfile.dart';
import '../Shared/newsScreen.dart';
import 'package:camsvirtusa/Shared/HardwareEnforcementWrapper.dart';

class StudentMainScreen extends StatefulWidget {
  final String studentId;
  final String? verificationTime;

  const StudentMainScreen({
    Key? key,
    required this.studentId,
    this.verificationTime,
  }) : super(key: key);

  @override
  _StudentMainScreenState createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int _currentIndex = 1; // 0: News, 1: Home, 2: Profile

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const NewsScreen(isTab: true), // We will pass isTab flag to prevent Scaffold appbar issues if needed
      StudentDashboard(
        studentId: widget.studentId,
        verificationTime: widget.verificationTime,
      ),
      StudentProfile(studentId: widget.studentId),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    return HardwareEnforcementWrapper(
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 600 ? 32 : 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: PhosphorIconsRegular.newspaper,
                    index: 0,
                    screenWidth: screenWidth,
                  ),
                  _buildNavItem(
                    icon: PhosphorIconsRegular.house,
                    index: 1,
                    screenWidth: screenWidth,
                  ),
                  _buildNavItem(
                    icon: PhosphorIconsRegular.user,
                    index: 2,
                    screenWidth: screenWidth,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required int index,
    required double screenWidth,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: const Color(0xFFF97316).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Icon(
          icon,
          size: screenWidth > 600 ? 36 : 28,
          color: isSelected ? const Color(0xFFF97316) : Colors.black54,
        ),
      ),
    );
  }
}
