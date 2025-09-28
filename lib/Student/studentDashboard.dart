import 'dart:async';
import 'dart:convert';

import 'package:camsvirtusa/Student/studentLeave.dart';
import 'package:camsvirtusa/Student/studentOd.dart';
import 'package:camsvirtusa/Student/studentTimetable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'studentProfile.dart';
import 'studentAttendance.dart';
import 'StudentCurriculum.dart';

class StudentDashboard extends StatefulWidget {
  final String studentId;

  const StudentDashboard({Key? key, required this.studentId}) : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? studentData;
  bool _isLoading = true;

  // News Bar Animation Controller
  late AnimationController _newsController;
  late Animation<Offset> _offsetAnimation;

  List<String> newsItems = [
    "Welcome to the new academic year! Registration is now open.",
    "Library timings updated: Now open from 8 AM to 8 PM",
    "Sports day scheduled for next Friday - All students are invited!",
    "New course offerings available - Check your student portal",
    "Campus maintenance scheduled for weekend - Some areas may be restricted"
  ];

  int currentNewsIndex = 0;

  // --- BLE Configuration (Updated to match faculty broadcaster) ---
  static const String SERVICE_UUID = "bf27730d-860a-4e09-889c-2d8b6a9e0fe7";
  static const String CHARACTERISTIC_UUID = "87654321-4321-4321-4321-CBA987654321";

  // BLE state
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  bool _isScanning = false;
  Set<String> _respondedSessions = {};
  String? _currentDetectedSession;
  bool _bluetoothReady = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _setupNewsAnimation();
    _initializeEverythingAutomatically(); // 🔥 Auto-initialize everything
  }

  @override
  void dispose() {
    _newsController.dispose();
    _stopScanning();
    super.dispose();
  }

  // 🔥 AUTOMATICALLY INITIALIZE ALL REQUIRED SERVICES
  Future<void> _initializeEverythingAutomatically() async {
    try {
      print("🚀 Auto-initializing all services...");

      // Step 1: Request all permissions automatically
      await _requestAllPermissions();

      // Step 2: Turn on Bluetooth automatically
      await _turnOnBluetoothAutomatically();

      // Step 3: Turn on Location services automatically
      await _turnOnLocationAutomatically();

      // Step 4: Start BLE scanning automatically
      await _startBLEAutomatically();

      print("✅ All services initialized successfully!");

    } catch (e) {
      print("❌ Error during auto-initialization: $e");
    }
  }

  // Auto-request all permissions
  Future<void> _requestAllPermissions() async {
    print("📋 Requesting all permissions...");

    final permissions = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.location,
      Permission.locationAlways,
      Permission.locationWhenInUse,
    ].request();

    // Check for denied permissions
    final deniedPermissions = permissions.entries
        .where((entry) => !entry.value.isGranted)
        .map((entry) => entry.key.toString())
        .toList();

    if (deniedPermissions.isNotEmpty) {
      print("⚠️ Some permissions denied: $deniedPermissions");

      // Show dialog to user about permissions
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Permissions Required"),
            content: Text("Please grant all permissions for attendance tracking to work properly."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings(); // Open system settings
                },
                child: Text("Settings"),
              ),
            ],
          ),
        );
      }
    } else {
      print("✅ All permissions granted!");
    }
  }

  // Auto-turn on Bluetooth
  Future<void> _turnOnBluetoothAutomatically() async {
    print("📱 Checking Bluetooth status...");

    if (!await FlutterBluePlus.isSupported) {
      print("❌ BLE not supported on this device");
      return;
    }

    var adapterState = await FlutterBluePlus.adapterState.first;

    if (adapterState != BluetoothAdapterState.on) {
      print("🔵 Turning ON Bluetooth automatically...");

      try {
        await FlutterBluePlus.turnOn();

        // Wait for Bluetooth to turn on
        await FlutterBluePlus.adapterState
            .firstWhere((state) => state == BluetoothAdapterState.on)
            .timeout(Duration(seconds: 10));

        print("✅ Bluetooth turned ON successfully!");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.bluetooth, color: Colors.white),
                  SizedBox(width: 8),
                  Text("Bluetooth turned ON automatically"),
                ],
              ),
              backgroundColor: Colors.blue,
            ),
          );
        }
      } catch (e) {
        print("❌ Failed to turn on Bluetooth: $e");
      }
    } else {
      print("✅ Bluetooth already ON");
    }

    setState(() => _bluetoothReady = true);
  }

  // Auto-turn on Location
  Future<void> _turnOnLocationAutomatically() async {
    print("📍 Checking Location status...");

    bool serviceEnabled = await Permission.location.serviceStatus.isEnabled;

    if (!serviceEnabled) {
      print("📍 Location services disabled, requesting to enable...");

      // Note: Flutter can't automatically turn on location services
      // But we can guide the user
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text("Location Required"),
            content: Text("Please enable Location services for Bluetooth scanning to work."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("OK"),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  openAppSettings();
                },
                child: Text("Settings"),
              ),
            ],
          ),
        );
      }
    } else {
      print("✅ Location services already enabled");
    }
  }

  // Auto-start BLE scanning
  Future<void> _startBLEAutomatically() async {
    if (!_bluetoothReady) {
      print("⏸️ Waiting for Bluetooth to be ready...");
      return;
    }

    print("🔍 Starting BLE scanning automatically...");

    if (_isScanning) return;

    try {
      FlutterBluePlus.startScan(
        withServices: [Guid(SERVICE_UUID)],
        timeout: const Duration(minutes: 30), // Longer timeout
        androidUsesFineLocation: true,
      );

      _scanSubscription = FlutterBluePlus.scanResults.listen(_handleScanResults);

      setState(() {
        _isScanning = true;
        _respondedSessions.clear();
      });

      print("✅ BLE scanning started successfully!");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.radar, color: Colors.white),
                SizedBox(width: 8),
                Text("Attendance detection active"),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print("❌ Failed to start BLE scanning: $e");
    }
  }

  void _stopScanning() {
    if (!_isScanning) return;

    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    setState(() => _isScanning = false);

    print("⏹️ Stopped BLE scanning");
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      try {
        final sessionJson = _extractSessionData(result);
        if (sessionJson == null) continue;

        final session = jsonDecode(sessionJson);
        final String sessionId = session['sessionId'];
        final String className = session['className'];
        final String subject = session['subject'] ?? 'Unknown';
        final String facultyId = session['facultyId'] ?? 'Unknown';

        if (_respondedSessions.contains(sessionId)) continue;

        // Only respond if session is for student's class
        if (studentData != null && className == studentData!['class']) {
          print("📡 Found matching attendance session:");
          print("   Session ID: $sessionId");
          print("   Class: $className");
          print("   Subject: $subject");
          print("   Faculty: $facultyId");

          _respondedSessions.add(sessionId);
          _currentDetectedSession = sessionId;

          // Send response to Firestore
          _sendAttendanceResponse(sessionId, subject, facultyId);
        }
      } catch (e) {
        print("❌ Error processing scan result: $e");
      }
    }
  }

  String? _extractSessionData(ScanResult result) {
    // Try manufacturer data first
    if (result.advertisementData.manufacturerData.isNotEmpty) {
      try {
        return utf8.decode(result.advertisementData.manufacturerData.values.first);
      } catch (e) {
        print("❌ Error decoding manufacturer data: $e");
      }
    }

    // Try service data
    if (result.advertisementData.serviceData.isNotEmpty) {
      try {
        return utf8.decode(result.advertisementData.serviceData.values.first);
      } catch (e) {
        print("❌ Error decoding service data: $e");
      }
    }

    return null;
  }

  // Send attendance response to Firestore
  // Send attendance response to Firestore with proper student name handling
  Future<void> _sendAttendanceResponse(String sessionId, String subject, String facultyId) async {
    try {
      // Ensure we have student data before proceeding
      if (studentData == null) {
        print("⚠️ Student data not loaded yet, fetching...");
        await _fetchData();
      }

      // Get student name with multiple fallback options
      String studentName = 'Unknown Student';
      if (studentData != null) {
        studentName = studentData!['name']?.toString() ??
            studentData!['fullName']?.toString() ??
            studentData!['student_name']?.toString() ??
            'Student_${widget.studentId}';
      }

      // Get student class for better identification
      String studentClass = studentData?['class']?.toString() ?? 'Unknown Class';

      print("📝 Preparing attendance response:");
      print("   Student ID: ${widget.studentId}");
      print("   Student Name: $studentName");
      print("   Student Class: $studentClass");
      print("   Session ID: $sessionId");
      print("   Subject: $subject");

      // Send the response with complete student information
      await FirebaseFirestore.instance
          .collection('attendance_responses')
          .add({
        'sessionId': sessionId,
        'studentId': widget.studentId,
        'studentName': studentName, // Properly retrieved student name
        'studentClass': studentClass, // Add class for better identification
        'timestamp': FieldValue.serverTimestamp(),
        'deviceId': '${widget.studentId}_${DateTime.now().millisecondsSinceEpoch}',
        'subject': subject,
        'facultyId': facultyId,
        'responseTime': DateTime.now().toIso8601String(), // Add local timestamp as backup
        'status': 'present', // Explicitly mark as present
      });

      print("✅ Attendance response sent successfully!");
      print("   Student Name in DB: $studentName");
      print("   Session: $sessionId");

      // Show success notification with student name
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('✅ Attendance marked!',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('Student: $studentName',
                          style: TextStyle(fontSize: 11)),
                      Text('Subject: $subject',
                          style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("❌ Error sending attendance response: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to mark attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Setup news animation
  void _setupNewsAnimation() {
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

  Future<void> _startNewsRotation() async {
    _newsController.forward();
    await Future.delayed(const Duration(seconds: 10));
    if (mounted) {
      setState(() {
        currentNewsIndex = (currentNewsIndex + 1) % newsItems.length;
      });
      _newsController.reset();
      _startNewsRotation();
    }
  }

  Future<void> _fetchData() async {
    try {
      var studentDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .get();

      if (!studentDoc.exists) throw Exception("Student not found");

      var data = studentDoc.data();
      if (data == null) throw Exception("Student record empty");

      double attendancePercent = await fetchAttendancePercentage();

      setState(() {
        studentData = data;
        studentData?['attendancePercent'] = attendancePercent.round();
        _isLoading = false;
      });
    } catch (e) {
      print("Error loading student data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading student data: $e')));
        setState(() {
          _isLoading = false;
          studentData = null;
        });
      }
    }
  }

  Future<double> fetchAttendancePercentage() async {
    try {
      var studentDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .get();

      if (!studentDoc.exists) return 0;
      Map<String, dynamic>? studentData = studentDoc.data();
      if (studentData == null) return 0;

      String? currentSemester = studentData['current_semester'];
      if (currentSemester == null) return 0;

      var attendanceDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .collection('attendance')
          .doc(currentSemester)
          .get();

      if (!attendanceDoc.exists) return 0;

      Map<String, dynamic>? attendanceData = attendanceDoc.data();
      if (attendanceData == null) return 0;

      var percent = attendanceData['P'];
      if (percent is num) {
        return percent.toDouble();
      }
      return 0;
    } catch (e) {
      print("Error fetching attendance percentage: $e");
      return 0;
    }
  }

  // Navigation methods
  void navigateToAttendance(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AttendancePage(studentId: widget.studentId),
      ),
    );
  }

  void navigateToTimeTable(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TimeTablePage(studentId: widget.studentId),
      ),
    );
  }

  void navigateToODForm(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OnDutyFormPage(studentId: widget.studentId),
      ),
    );
  }

  void navigateToLeaveForm(String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeaveApplicationForm(studentId: widget.studentId),
      ),
    );
  }

  void _goToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudentCurriculum(studentId: widget.studentId),
      ),
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
        color: const Color(0xFFFF7F50),
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

  Widget _buildBottomNavigationBar() {
    final mediaQuery = MediaQuery.of(context);
    final double bottomSafeArea = mediaQuery.padding.bottom;
    final double screenWidth = mediaQuery.size.width;

    return Container(
      height: 70 + bottomSafeArea,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
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
              onPressed: _goToSearch,
            ),
            IconButton(
              icon: Image.asset(
                "assets/homeLogo.png",
                height: screenWidth > 600 ? 36 : 32,
              ),
              onPressed: () {},
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
                    builder: (_) => StudentProfile(studentId: widget.studentId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double screenWidth = mediaQuery.size.width;

    final name = studentData?['name']?.toString() ?? '';
    final attendancePercent = studentData?['attendancePercent'] ?? 0;
    var p = attendancePercent;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Center(
          child: Text(
            'STUDENT DASHBOARD',
            style: TextStyle(
              color: Colors.white,
              fontSize: screenWidth > 600 ? 30 : 22,
            ),
          ),
        ),
        backgroundColor: const Color(0xFFFF7F50),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                // Auto-detection status
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isScanning ? Colors.green : Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isScanning ? Icons.radar : Icons.radar_outlined,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        _isScanning ? 'AUTO' : 'OFF',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: _isLoading
            ? Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text("Initializing services..."),
              SizedBox(height: 8),
              Text(
                "Please wait while we set up attendance detection",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        )
            : Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth > 600 ? 24 : 16,
            vertical: 16,
          ),
          child: Column(
            children: [
              // User Welcome Section
              Row(
                children: [
                  CircleAvatar(
                    radius: screenWidth > 600 ? 35 : 30,
                    backgroundImage: const AssetImage('assets/account.png'),
                  ),
                  SizedBox(width: screenWidth > 600 ? 20 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome $name...!!",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: screenWidth > 600 ? 22 : 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        // Auto-detection status
                        Container(
                          margin: EdgeInsets.only(top: 4),
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _isScanning ? Colors.green.shade100 : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isScanning ? '🎯 Auto-attendance active' : '⚠️ Detection inactive',
                            style: TextStyle(
                              color: _isScanning ? Colors.green.shade700 : Colors.orange.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_currentDetectedSession != null)
                          Container(
                            margin: EdgeInsets.only(top: 2),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Last: ${_currentDetectedSession?.substring(_currentDetectedSession!.length - 8) ?? "None"}',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 9,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight > 600 ? 32 : 24),

              // Attendance Section
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Attendance:",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: screenWidth > 600 ? 20 : 18,
                      ),
                    ),
                  ),
                  Container(
                    width: screenWidth > 600 ? 250 : 200,
                    height: screenWidth > 600 ? 25 : 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: const Color(0xFFe51f1f),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: (screenWidth > 600 ? 246 : 196),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: const Color(0xFF44ce1b),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: const Color(0xFFe51f1f),
                            ),
                            width: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "$attendancePercent%",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: screenWidth > 600 ? 16 : 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight > 600 ? 24 : 16),

              // News Bar
              _buildNewsBar(),

              SizedBox(height: screenHeight > 600 ? 24 : 16),

              // Dashboard Grid
              _buildDashboardGrid(context),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDashboardGrid(BuildContext context) {
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenWidth = mediaQuery.size.width;

    return Expanded(
      child: GridView.count(
        padding: EdgeInsets.all(screenWidth > 600 ? 24.0 : 16.0),
        crossAxisCount: screenWidth > 800 ? 3 : 2,
        crossAxisSpacing: screenWidth > 600 ? 20 : 16,
        mainAxisSpacing: screenWidth > 600 ? 20 : 16,
        childAspectRatio: screenWidth > 600 ? 1.1 : 1.0,
        children: [
          _buildDashboardCard(
            context,
            label: "TIME TABLE",
            imagePath: "assets/timetable_ad.png",
            onTap: () => navigateToTimeTable("Time Table"),
          ),
          _buildDashboardCard(
            context,
            label: "ATTENDANCE",
            imagePath: "assets/Attendance.png",
            onTap: () => navigateToAttendance("Attendance"),
          ),
          _buildDashboardCard(
            context,
            label: "ON DUTY FORM",
            imagePath: "assets/ODForm.png",
            onTap: () => navigateToODForm("On Duty Form"),
          ),
          _buildDashboardCard(
            context,
            label: "LEAVE FORM",
            imagePath: "assets/LeaveForm.png",
            onTap: () => navigateToLeaveForm("Leave Form"),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
      BuildContext context, {
        required String label,
        required String imagePath,
        required VoidCallback onTap,
      }) {
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
              Image.asset(
                imagePath,
                height: screenWidth > 800 ? 80
                    : screenWidth > 600 ? 54
                    : 40,
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



//in the above code the student dashboard is perfectly showing that attendance marked when i clieck the boardcast button in markattednace page but the student name is now showing in the live studetns signals