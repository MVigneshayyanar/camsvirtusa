import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'facultyDashboard.dart';
import 'facultyProfile.dart';
import '../Shared/newsScreen.dart';
import 'package:camsvirtusa/Shared/HardwareEnforcementWrapper.dart';

class FacultyMainScreen extends StatefulWidget {
  final String facultyId;

  const FacultyMainScreen({
    Key? key,
    required this.facultyId,
  }) : super(key: key);

  @override
  _FacultyMainScreenState createState() => _FacultyMainScreenState();
}

class _FacultyMainScreenState extends State<FacultyMainScreen> {
  int _currentIndex = 1; // 0: News, 1: Home, 2: Profile

  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      const NewsScreen(isTab: true),
      FacultyDashboard(
        facultyId: widget.facultyId,
      ),
      FacultyProfile(facultyId: widget.facultyId),
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
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7F50), // Orange
                      borderRadius: BorderRadius.circular(40),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF7F50).withOpacity(0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
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
              ],
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

    // Scale items on smaller screen sizes to prevent overflow
    final isSmallScreen = screenWidth < 360;
    final paddingHorizontal = isSmallScreen ? 12.0 : 16.0;
    final paddingVertical = isSmallScreen ? 8.0 : 12.0;
    final iconSize = isSmallScreen ? 18.0 : 22.0;
    final fontSize = isSmallScreen ? 11.0 : 13.0;

    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: paddingHorizontal, vertical: paddingVertical),
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
              size: iconSize,
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            ),
            if (isSelected) ...[
              SizedBox(width: isSmallScreen ? 6.0 : 8.0),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: fontSize,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
