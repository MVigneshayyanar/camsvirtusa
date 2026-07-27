import 'package:camsvirtusa/Shared/newsScreen.dart';
import '../Shared/latestNewsWidget.dart';
import '../Shared/todayScheduleWidget.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:camsvirtusa/Student/studentLeave.dart';
import 'package:camsvirtusa/Student/studentOd.dart';
import 'package:camsvirtusa/Student/studentTimetable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'studentAttendance.dart';

class StudentDashboard extends StatefulWidget {
  final String studentId;
  final String? verificationTime;

  const StudentDashboard(
      {Key? key, required this.studentId, this.verificationTime})
      : super(key: key);

  @override
  _StudentDashboardState createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  Map<String, dynamic>? studentData;
  bool _isLoading = true;
  Timer? _attendanceTimer;
  bool _isAttendanceActive = true;
  int _secondsRemaining = 180;

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
  static const String SERVICE_UUID = 'bf27730d-860a-4e09-889c-2d8b6a9e0fe7';
  static const String CHARACTERISTIC_UUID = 'bf27730d-860a-4e09-889c-2d8b6a9e0fe8';

  // BLE state
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  bool _isScanning = false;
  Set<String> _respondedSessions = {};
  String? _currentDetectedSession;
  bool _bluetoothReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupNewsAnimation();
    _startAttendanceTimer();
    _fetchData().then((_) {
      if (_isAttendanceActive) {
        _initializeEverythingAutomatically();
      }
    });
  }

  void _startAttendanceTimer() async {
    DateTime? verifyTime;
    if (widget.verificationTime != null) {
      verifyTime = DateTime.tryParse(widget.verificationTime!);
    } else {
      final prefs = await SharedPreferences.getInstance();
      final lastVerify = prefs.getString('lastVerificationTime');
      if (lastVerify != null) verifyTime = DateTime.tryParse(lastVerify);
    }

    if (verifyTime == null ||
        DateTime.now().difference(verifyTime).inMinutes >= 3) {
      _deactivateAttendance();
      return;
    }

    if (mounted) {
      setState(() {
        _secondsRemaining =
            180 - DateTime.now().difference(verifyTime!).inSeconds;
      });
    }

    _attendanceTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      int seconds = 180 - DateTime.now().difference(verifyTime!).inSeconds;

      if (seconds <= 0) {
        _deactivateAttendance();
        timer.cancel();
        _showReverificationPopup();
      } else {
        setState(() {
          _secondsRemaining = seconds;
        });
      }
    });
  }

  void _showReverificationPopup() {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.0),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Custom Icon/Illustration
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFFF7F50).withOpacity(0.1),
                  ),
                  child: const Icon(
                    Icons.face_retouching_natural_rounded,
                    color: Color(0xFFFF7F50),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 24),
                // Title
                const Text(
                  "Verify Face Again!",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                // Description
                const Text(
                  "Your attendance session has timed out. Verify your face again to reactivate detection.",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Colors.black12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Skip",
                          style: TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          Navigator.pushReplacementNamed(
                            context,
                            '/faceVerification',
                            arguments: widget.studentId,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7F50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Verify Now",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deactivateAttendance() {
    if (mounted) {
      _stopScanning();
      setState(() {
        _isAttendanceActive = false;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attendanceTimer?.cancel();
    _adapterStateSubscription?.cancel();
    _newsController.dispose();
    _stopScanning();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      print("📱 App resumed - Rechecking permissions & services...");
      if (_isAttendanceActive) {
        _initializeEverythingAutomatically();
      }
    }
  }

  // 🔥 AUTOMATICALLY INITIALIZE ALL REQUIRED SERVICES
  Future<void> _initializeEverythingAutomatically() async {
    try {
      print("🚀 Auto-initializing all services...");

      // Step 1: Request all permissions automatically
      await _requestAllPermissions();

      // Setup live monitoring of Bluetooth state changes
      _adapterStateSubscription?.cancel();
      _adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
        if (state != BluetoothAdapterState.on) {
          if (_bluetoothReady) {
            setState(() {
              _bluetoothReady = false;
              _isScanning = false;
            });
            _turnOnBluetoothAutomatically();
          }
        } else {
          if (!_bluetoothReady) {
            setState(() {
              _bluetoothReady = true;
            });
            _startBLEAutomatically();
          }
        }
      });

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
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
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
            content: Text(
                "Please grant all permissions for attendance tracking to work properly."),
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
            .timeout(Duration(seconds: 4));

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

        // Show dialog asking user to enable Bluetooth manually (essential for Android 13+)
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text("Bluetooth Required"),
              content: const Text(
                  "Please turn on Bluetooth in your device settings to scan for attendance."),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("OK"),
                ),
              ],
            ),
          );
        }
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
            content: Text(
                "Please enable Location services for Bluetooth scanning to work."),
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
      await FlutterBluePlus.startScan(
        withServices: [Guid(SERVICE_UUID)],
        timeout: const Duration(minutes: 30),
        androidUsesFineLocation: true,
      );

      _scanSubscription =
          FlutterBluePlus.scanResults.listen(_handleScanResults);

      setState(() {
        _isScanning = true;
        _respondedSessions.clear();
      });

      print("✅ BLE scanning started successfully!");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
    if (mounted) {
      setState(() => _isScanning = false);
    }

    print("⏹️ Stopped BLE scanning");
  }

  void _handleScanResults(List<ScanResult> results) async {
    for (final result in results) {
      try {
        final deviceId = result.device.remoteId.str;
        if (_respondedSessions.contains(deviceId)) continue;

        // Check if it's our beacon by manufacturer data or service UUID
        bool isOurBeacon = false;
        Uint8List? token;

        for (final uuid in result.advertisementData.serviceUuids) {
          if (uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
            isOurBeacon = true;
            break;
          }
        }

        if (result.advertisementData.manufacturerData.containsKey(0xFFFF)) {
          isOurBeacon = true;
          final mData = result.advertisementData.manufacturerData[0xFFFF]!;
          if (mData.length >= 4) {
             token = Uint8List.fromList(mData.sublist(0, 4));
          }
        }

        if (isOurBeacon && token != null && token.length == 4) {
          _respondedSessions.add(deviceId); // Mark as in-progress/done to prevent multiple attempts
          
          print("📡 [BLE-BEACON] Found faculty GATT server. Connecting...");
          
          // Randomized jitter (0 - 15 seconds) to avoid GATT connection floods
          final jitterMs = Random().nextInt(15000);
          print("⏳ Waiting ${jitterMs}ms before connecting to avoid floods...");
          await Future.delayed(Duration(milliseconds: jitterMs));

          try {
            await result.device.connect(license: License.nonprofit);
            print("✅ Connected to GATT server!");

            final services = await result.device.discoverServices();
            BluetoothService? targetService;
            for (var s in services) {
              if (s.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
                targetService = s;
                break;
              }
            }

            if (targetService != null) {
              BluetoothCharacteristic? targetChar;
              for (var c in targetService.characteristics) {
                if (c.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
                  targetChar = c;
                  break;
                }
              }

              if (targetChar != null) {
                // Construct payload: 4-byte token + student ID
                final studentIdBytes = utf8.encode(widget.studentId);
                final payload = Uint8List(4 + studentIdBytes.length);
                for (int i = 0; i < 4; i++) payload[i] = token[i];
                for (int i = 0; i < studentIdBytes.length; i++) payload[i + 4] = studentIdBytes[i];

                await targetChar.write(payload, withoutResponse: false);
                print("✅ Successfully wrote attendance to faculty GATT Server!");

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 8),
                          Text('✅ Attendance submitted to faculty!'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 4),
                    ),
                  );
                }
              }
            }
          } catch (e) {
            print("❌ GATT Connection/Write failed: $e");
            _respondedSessions.remove(deviceId); // Allow retry on failure
          } finally {
            await result.device.disconnect();
          }
        }
      } catch (e) {
        print("❌ Error processing scan result: $e");
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
      if (newsItems.isNotEmpty) {
        setState(() {
          currentNewsIndex = (currentNewsIndex + 1) % newsItems.length;
        });
      }
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

      String currentSemester = 'V'; // Default fallback
      final department = studentData['department'];
      final className = studentData['class'];

      if (department != null && className != null) {
        final classDoc = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('departments')
            .collection('all_departments')
            .doc(department)
            .collection('clasees')
            .doc(className)
            .get();

        if (classDoc.exists) {
          final classData = classDoc.data()!;
          final semesterField = classData['currentSemester'];
          if (semesterField is Map) {
            currentSemester =
                semesterField['semester']?.toString() ?? currentSemester;
          } else if (semesterField != null) {
            currentSemester = semesterField.toString();
          }
        }
      }

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

      var percent = 0.0;
      var totalMarks = 0;
      var presentCount = 0;

      attendanceData.forEach((key, value) {
        if (key == 'P' || key == 'A' || key == 'OD') return;
        if (value is Map) {
          value.forEach((hourStr, subjectMap) {
            if (subjectMap is Map) {
              subjectMap.forEach((subject, status) {
                totalMarks++;
                if (status.toString().toUpperCase() == 'P') {
                  presentCount++;
                }
              });
            }
          });
        }
      });

      if (totalMarks > 0) {
        percent = (presentCount / totalMarks) * 100;
      }
      return percent;
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
        backgroundColor: const Color(0xFFFF7F50),
        title: Center(
          child: Text(
            'STUDENT DASHBOARD',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
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
                        _isScanning
                            ? '${(_secondsRemaining ~/ 60).toString().padLeft(2, '0')}:${(_secondsRemaining % 60).toString().padLeft(2, '0')} AUTO'
                            : 'OFF',
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
                    if (!_isAttendanceActive)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Attendance Deactivated (Timeout)",
                              style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/faceVerification',
                                  arguments: widget.studentId,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text("Verify Face Again",
                                  style: TextStyle(color: Colors.white)),
                            )
                          ],
                        ),
                      ),
                    // User Welcome Section
                    Row(
                      children: [
                        CircleAvatar(
                          radius: screenWidth > 600 ? 35 : 30,
                          backgroundColor:
                              const Color(0xFFFF8C61).withOpacity(0.12),
                          child: Icon(
                            PhosphorIconsRegular.user,
                            size: screenWidth > 600 ? 35 : 30,
                            color: const Color(0xFFFF8C61),
                          ),
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _isScanning
                                      ? Colors.green.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  !_isScanning
                                      ? '⚠️ Detection inactive'
                                      : (_currentDetectedSession != null
                                          ? '⚡ Class active - Scanning...'
                                          : '🎯 Scanning for class...'),
                                  style: TextStyle(
                                    color: _isScanning
                                        ? Colors.green.shade700
                                        : Colors.orange.shade700,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (_currentDetectedSession != null)
                                Container(
                                  margin: EdgeInsets.only(top: 2),
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
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
                    SizedBox(height: screenHeight > 600 ? 16 : 12),

                    // Today's Schedule Banner
                    TodayScheduleWidget(
                        userType: 'student', userId: widget.studentId),
                    SizedBox(height: screenHeight > 600 ? 16 : 12),

                    // Attendance Section
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Attendance:",
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: screenWidth > 600 ? 17.5 : 15.5,
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
                                width: (screenWidth > 600 ? 250.0 : 200.0) *
                                    ((attendancePercent as num).toDouble() /
                                            100.0)
                                        .clamp(0.0, 1.0),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: const Color(0xFF44ce1b),
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
                    SizedBox(height: screenHeight > 600 ? 16 : 12),

                    // News Bar
                    const LatestNewsWidget(),

                    SizedBox(height: screenHeight > 600 ? 16 : 12),

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
        padding: EdgeInsets.all(screenWidth > 600 ? 24.0 : 16.0),
        crossAxisCount: screenWidth > 800 ? 3 : 2,
        crossAxisSpacing: screenWidth > 600 ? 20 : 16,
        mainAxisSpacing: screenWidth > 600 ? 20 : 16,
        childAspectRatio: screenWidth > 600 ? 1.1 : 1.0,
        children: [
          _buildDashboardCard(
            context,
            label: "TIME TABLE",
            icon: PhosphorIconsRegular.calendarBlank,
            onTap: () => navigateToTimeTable("Time Table"),
          ),
          _buildDashboardCard(
            context,
            label: "ATTENDANCE",
            icon: PhosphorIconsRegular.checkSquare,
            onTap: () => navigateToAttendance("Attendance"),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context, {
    required String label,
    required IconData icon,
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

//in the above code the student dashboard is perfectly showing that attendance marked when i clieck the boardcast button in markattednace page but the student name is now showing in the live studetns signals
