import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../Shared/latestNewsWidget.dart';
import 'package:camsvirtusa/Shared/newsScreen.dart';
import '../Shared/todayScheduleWidget.dart';
import 'facultyTimetable.dart';
import 'facultyProfile.dart';
import 'MarkAttendance.dart';
import 'facultyMentees.dart';

class FacultyDashboard extends StatefulWidget {
  final String facultyId;

  const FacultyDashboard({super.key, required this.facultyId});

  @override
  _FacultyDashboardState createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? facultyData;
  bool _isLoading = true;
  String _nextClassText = "Loading schedule...";

  // News Bar Animation Controller
  late AnimationController _newsController;
  late Animation<Offset> _offsetAnimation;

  List<String> newsItems = [
    "Faculty meeting scheduled for tomorrow at 3 PM in the conference room.",
    "New curriculum guidelines have been updated - Please check your email",
    "Student evaluation forms are now available on the faculty portal",
    "Workshop on digital teaching methods this Friday - Registration open",
    "Reminder: Submit semester grades by end of this week"
  ];

  int currentNewsIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchFacultyData();

    // Initialize news animation
    _newsController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _newsController,
      curve: Curves.easeInOut,
    ));

    _startNewsRotation();
  }

  @override
  void dispose() {
    _newsController.dispose();
    super.dispose();
  }

  void _startNewsRotation() {
    _newsController.forward();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        if (newsItems.isNotEmpty) {
          setState(() {
            currentNewsIndex = (currentNewsIndex + 1) % newsItems.length;
          });
        }
        _newsController.reset();
        _startNewsRotation();
      }
    });
  }

  Future<void> _fetchFacultyData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('faculties')
          .collection('all_faculties')
          .doc(widget.facultyId)
          .get();
      if (doc.exists) {
        setState(() {
          facultyData = doc.data();
          _isLoading = false;
        });
        _fetchNextClass();
      } else {
        setState(() {
          facultyData = {'name': 'Unknown Faculty'};
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        facultyData = {'name': 'Error loading data'};
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load faculty data: $e')),
      );
    }
  }

  Future<void> _fetchNextClass() async {
    try {
      final String? dept = facultyData?['department'];
      final List? assigned = facultyData?['classes'];
      if (dept == null || assigned == null || assigned.isEmpty) {
        setState(() {
          _nextClassText = "No classes assigned";
        });
        return;
      }

      final now = DateTime.now();
      final daysOfWeek = [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday"
      ];
      final String today = daysOfWeek[now.weekday - 1];

      if (today == "Saturday" || today == "Sunday") {
        setState(() {
          _nextClassText = "No classes today (Weekend)";
        });
        return;
      }

      final periodStartTimes = [
        DateTime(now.year, now.month, now.day, 9, 0),
        DateTime(now.year, now.month, now.day, 9, 50),
        DateTime(now.year, now.month, now.day, 10, 55),
        DateTime(now.year, now.month, now.day, 11, 45),
        DateTime(now.year, now.month, now.day, 13, 25),
        DateTime(now.year, now.month, now.day, 14, 15),
        DateTime(now.year, now.month, now.day, 15, 20),
      ];

      int currentPeriodIdx = -1;
      for (int i = 0; i < periodStartTimes.length; i++) {
        if (now.isBefore(periodStartTimes[i])) {
          currentPeriodIdx = i;
          break;
        }
      }

      if (currentPeriodIdx == -1) {
        setState(() {
          _nextClassText = "No more classes today";
        });
        return;
      }

      for (var className in assigned) {
        final classDoc = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('departments')
            .collection('all_departments')
            .doc(dept)
            .collection('clasees')
            .doc(className.toString())
            .get();

        if (classDoc.exists) {
          final data = classDoc.data() as Map<String, dynamic>;
          final semField = data['currentSemester'];
          String sem = 'V';
          if (semField is Map) {
            sem = semField['semester']?.toString() ?? 'V';
          } else {
            sem = semField?.toString() ?? 'V';
          }

          final timetables = data['timetables'] as Map?;
          final mappings = data['courseMapping'] as Map?;

          if (timetables != null && mappings != null) {
            final semTimetable = timetables[sem] as Map?;
            final semMappings = mappings[sem] as List?;
            if (semTimetable != null && semMappings != null) {
              final todayPeriods = semTimetable[today] as List?;
              if (todayPeriods != null) {
                for (int i = currentPeriodIdx; i < todayPeriods.length; i++) {
                  final String abbrev = todayPeriods[i]?.toString() ?? "";
                  if (abbrev.isNotEmpty && abbrev != "-") {
                    final mapping = semMappings.firstWhere((m) {
                      final mapData = m as Map?;
                      if (mapData == null) return false;
                      if (mapData['abbreviation']?.toString().toLowerCase() !=
                          abbrev.toLowerCase()) return false;

                      final isPrimaryFaculty =
                          mapData['facultyId']?.toString().toUpperCase() ==
                              widget.facultyId.toUpperCase();
                      final isSecondaryFaculty =
                          mapData['isElective'] == true &&
                              mapData['facultyId2']?.toString().toUpperCase() ==
                                  widget.facultyId.toUpperCase();

                      return isPrimaryFaculty || isSecondaryFaculty;
                    }, orElse: () => null);

                    if (mapping != null) {
                      final timeLabels = [
                        "9:00 AM",
                        "9:50 AM",
                        "10:55 AM",
                        "11:45 AM",
                        "1:25 PM",
                        "2:15 PM",
                        "3:20 PM"
                      ];
                      setState(() {
                        _nextClassText =
                            "$className | $abbrev | Period ${i + 1} (${timeLabels[i]})";
                      });
                      return;
                    }
                  }
                }
              }
            }
          }
        }
      }

      setState(() {
        _nextClassText = "No classes remaining today";
      });
    } catch (e) {
      setState(() {
        _nextClassText = "Next class offline";
      });
    }
  }

  void _navigateToProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacultyProfile(facultyId: widget.facultyId),
      ),
    );
  }

  void _navigateToMarkAttendance() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkAttendance(facultyId: widget.facultyId),
      ),
    );
  }

  void navigateToTimeTable() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimeTablePage(facultyId: widget.facultyId),
      ),
    );
  }

  void _navigateToMentees() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacultyMenteesPage(facultyId: widget.facultyId),
      ),
    );
  }

  void _navigateToODRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacultyODRequestsPage(facultyId: widget.facultyId),
      ),
    );
  }

  void _goToNews() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewsScreen()),
    );
  }

  Widget _buildNewsBar() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: screenWidth > 600 ? 24 : 16,
        vertical: 8,
      ),
      padding: EdgeInsets.all(screenWidth > 600 ? 16 : 12),
      decoration: BoxDecoration(
        color:
            const Color(0xFFFF6B47), // Slightly darker than your app bar color
        borderRadius: BorderRadius.circular(screenWidth > 600 ? 12 : 10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.campaign,
              color: Colors.white,
              size: screenWidth > 600 ? 24 : 20,
            ),
          ),
          SizedBox(width: screenWidth > 600 ? 16 : 12),
          Expanded(
            child: SlideTransition(
              position: _offsetAnimation,
              child: Text(
                newsItems[currentNewsIndex],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth > 600 ? 16 : 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          SizedBox(width: screenWidth > 600 ? 12 : 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              "NEW",
              style: TextStyle(
                color: Colors.white,
                fontSize: screenWidth > 600 ? 12 : 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get media query data for responsive design
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double screenWidth = mediaQuery.size.width;

    final name = facultyData?['name']?.toString() ?? '';

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        centerTitle: false,
        title: Text(
          'FACULTY DASHBOARD',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth > 600 ? 24 : 16, // Responsive padding
            vertical: 16,
          ),
          child: Column(
            children: [
              // User Welcome Section
              Row(
                children: [
                  CircleAvatar(
                    radius:
                        screenWidth > 600 ? 35 : 30, // Responsive avatar size
                    backgroundColor: const Color(0xFFFF8C61).withOpacity(0.12),
                    child: Icon(
                      PhosphorIconsRegular.user,
                      size: screenWidth > 600 ? 35 : 30,
                      color: const Color(0xFFFF8C61),
                    ),
                  ),
                  SizedBox(width: screenWidth > 600 ? 20 : 16),
                  Expanded(
                    child: Text(
                      "Welcome $name...!!",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize:
                            screenWidth > 600 ? 22 : 18, // Responsive font size
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Today's Schedule Banner
              TodayScheduleWidget(
                  userType: 'faculty', userId: widget.facultyId),
              const SizedBox(height: 16),

              // News Bar - Added here
              const LatestNewsWidget(),

              SizedBox(height: screenHeight > 600 ? 24 : 16),

              // Dashboard Grid
              _buildDashboardGrid(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardGrid(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;

    return Expanded(
      child: GridView.count(
        padding: EdgeInsets.all(
            screenWidth > 600 ? 24.0 : 16.0), // Responsive padding
        crossAxisCount:
            screenWidth > 800 ? 3 : 2, // More columns on larger screens
        crossAxisSpacing: screenWidth > 600 ? 20 : 16, // Responsive spacing
        mainAxisSpacing: screenWidth > 600 ? 20 : 16,
        childAspectRatio:
            screenWidth > 600 ? 1.1 : 1.0, // Better aspect ratio on tablets
        children: [
          _buildDashboardCard(
            context,
            label: "TIME TABLE",
            icon: PhosphorIconsRegular.calendarBlank,
            onTap: navigateToTimeTable,
          ),
          _buildDashboardCard(
            context,
            label: "MARK ATTENDANCE",
            icon: PhosphorIconsRegular.checkSquare,
            onTap: _navigateToMarkAttendance,
          ),
          _buildDashboardCard(
            context,
            label: "MY MENTEES",
            icon: PhosphorIconsRegular.users,
            onTap: _navigateToMentees,
          ),
          _buildDashboardCard(
            context,
            label: "OD REQUESTS",
            icon: PhosphorIconsRegular.clipboardText,
            onTap: _navigateToODRequests,
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context,
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(screenWidth > 600 ? 15 : 10),
      ),
      color: const Color(0xFF36454F),
      elevation: screenWidth > 600 ? 6 : 4,
      child: InkWell(
        borderRadius: BorderRadius.circular(screenWidth > 600 ? 15 : 10),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(screenWidth > 600 ? 16 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: screenWidth > 800
                    ? 80
                    : screenWidth > 600
                        ? 54
                        : 40,
                color: Colors.white,
              ),
              SizedBox(height: screenWidth > 600 ? 12 : 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: screenWidth > 600 ? 18 : 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
