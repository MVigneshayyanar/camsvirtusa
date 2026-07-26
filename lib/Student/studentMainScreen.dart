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
      const NewsScreen(
          isTab:
              true), // We will pass isTab flag to prevent Scaffold appbar issues if needed
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
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF97316), // Orange
            borderRadius: BorderRadius.circular(40),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF97316).withOpacity(0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: PhosphorIconsRegular.newspaper,
                    label: "News",
                    index: 0,
                    screenWidth: screenWidth,
                  ),
                  _buildNavItem(
                    icon: PhosphorIconsRegular.house,
                    label: "Home",
                    index: 1,
                    screenWidth: screenWidth,
                  ),
                  _buildNavItem(
                    icon: PhosphorIconsRegular.user,
                    label: "Profile",
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
    required String label,
    required int index,
    required double screenWidth,
  }) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: isSelected
            ? BoxDecoration(
                color: Colors.black.withOpacity(0.3), // Darker capsule overlay
                borderRadius: BorderRadius.circular(30),
              )
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
