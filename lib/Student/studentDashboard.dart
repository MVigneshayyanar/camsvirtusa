import 'package:camsvirtusa/Shared/newsScreen.dart';
import '../Shared/latestNewsWidget.dart';
import '../Shared/todayScheduleWidget.dart';
import 'dart:async';
import 'dart:convert';

import 'package:camsvirtusa/Student/studentLeave.dart';
import 'package:camsvirtusa/Student/studentOd.dart';
import 'package:camsvirtusa/Student/studentTimetable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'studentProfile.dart';
import 'studentAttendance.dart';
import 'StudentCurriculum.dart';
import 'package:camsvirtusa/Services/offline_attendance_queue.dart';

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
  // Faculty broadcasts with this prefix in localName: 'FAC_[sessionId]'
  // Student responds with this prefix in localName: 'STU_[studentId]'
  // Service UUID used to filter BLE scans on both sides
  static const String STUDENT_ADV_SERVICE_UUID = "0000aabb-0000-1000-8000-00805f9b34fb";
  static const double PROXIMITY_RADIUS_METERS =
      100.0; // Max distance from faculty to be marked present

  // BLE state
  bool _blePeripheralInitialized = false; // Track initialization to avoid re-init crash
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSubscription;
  StreamSubscription<DocumentSnapshot>? _firestoreSessionSubscription;
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
        _startFirestoreSessionListener();
      }
      OfflineAttendanceQueue
          .syncQueuedAttendance(); // Sync offline queue if back online
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
      _firestoreSessionSubscription?.cancel();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _attendanceTimer?.cancel();
    _adapterStateSubscription?.cancel();
    _firestoreSessionSubscription?.cancel();
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
      OfflineAttendanceQueue
          .syncQueuedAttendance(); // Sync any offline queued attendance
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

  // Auto-turn on Location (GPS hidden / skipped)
  Future<void> _turnOnLocationAutomatically() async {
    print("📍 Location check skipped (GPS hidden for attendance)");
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
        timeout: const Duration(minutes: 30), // Longer timeout
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
    if (mounted) {
      setState(() => _isScanning = false);
    }

    print("⏹️ Stopped BLE scanning");
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final result in results) {
      try {
        // Path A: Try to decode manufacturer data payload directly
        final payload = _extractSessionData(result);
        if (payload != null) {
          final parts = payload.split('|');
          if (parts.length >= 2) {
            final String sessionId = parts[0];
            final String className = parts[1];

            if (_respondedSessions.contains(sessionId)) continue;

            if (studentData != null && className == studentData!['class']) {
              print(
                  "📡 [BLE-PAYLOAD] Found matching attendance session: $sessionId");
              _respondedSessions.add(sessionId);
              _currentDetectedSession = sessionId;
              _fetchActiveSessionDetailsAndRespond(sessionId, className);
            }
            continue;
          }
        }

        // Path B: Detect Connectionless Faculty Beacon ('FAC_' prefix)
        // This is 100% offline capable because the sessionId is broadcasted directly in the localName!
        String advName = result.advertisementData.advName;
        if (advName.isEmpty) advName = result.advertisementData.localName;
        if (advName.isEmpty) advName = result.device.platformName;

        if (advName.startsWith('FAC_')) {
          final payload = advName.substring(4);
          final parts = payload.split('_');
          final sessionId = parts[0];
          final proximityToken = parts.length > 1 ? parts[1] : null;

          if (sessionId.isNotEmpty && !_respondedSessions.contains(sessionId)) {
            print(
                "📡 [BLE-BEACON] Found connectionless Faculty session: $sessionId (Token: $proximityToken)");
            _respondedSessions.add(sessionId);
            _currentDetectedSession = sessionId;

            _sendAttendanceResponse(sessionId, "Class Session", sessionId,
                proximityToken: proximityToken);
          }
        }
      } catch (e) {
        print("❌ Error processing scan result: $e");
      }
    }
  }

  /// Firestore real-time listener: watches the student's class document
  /// for activeSession changes. Checks GPS proximity to faculty before marking.
  void _startFirestoreSessionListener() {
    if (studentData == null) return;
    final deptId = studentData?['department']?.toString() ?? '';
    final className = studentData?['class']?.toString() ?? '';
    if (deptId.isEmpty || className.isEmpty) return;

    _firestoreSessionSubscription?.cancel();
    _firestoreSessionSubscription = FirebaseFirestore.instance
        .collection('colleges')
        .doc('departments')
        .collection('all_departments')
        .doc(deptId)
        .collection('clasees')
        .doc(className)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      final activeSession = data?['activeSession'] as Map<String, dynamic>?;
      if (activeSession == null) {
        setState(() => _currentDetectedSession = null);
        return;
      }

      final sessionId = activeSession['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty) return;
      if (_respondedSessions.contains(sessionId)) return;

      setState(() => _currentDetectedSession = sessionId);

      // Verify GPS proximity before marking attendance
      _verifyProximityAndRespond(activeSession);
    }, onError: (e) {
      print("\u26a0\ufe0f Firestore session listener error: $e");
    });

    print("\u2705 Firestore session listener started for class: $className");
  }

  /// Verify session and mark attendance immediately (GPS distance check hidden/disabled)
  Future<void> _verifyProximityAndRespond(
      Map<String, dynamic> activeSession) async {
    final sessionId = activeSession['sessionId']?.toString() ?? '';
    final subject = activeSession['subject']?.toString() ?? 'Class Session';
    final facultyId = activeSession['facultyId']?.toString() ?? '';

    if (sessionId.isEmpty || _respondedSessions.contains(sessionId)) return;

    print(
        "✅ BLE/Session detected ($sessionId) — marking present without GPS check (GPS hidden)!");
    _respondedSessions.add(sessionId);
    _sendAttendanceResponse(sessionId, subject, facultyId);
  }

  /// Check Firestore for an active session for the given class (used by BLE beacon detection path)
  Future<void> _checkFirestoreForActiveSession(String className) async {
    try {
      final deptId = studentData?['department']?.toString() ?? '';
      if (deptId.isEmpty) return;

      final classDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(deptId)
          .collection('clasees')
          .doc(className)
          .get();

      if (!classDoc.exists) return;
      final classData = classDoc.data();
      final activeSession =
          classData?['activeSession'] as Map<String, dynamic>?;
      if (activeSession == null) return;

      final sessionId = activeSession['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty || _respondedSessions.contains(sessionId)) return;

      print("📡 [BLE-BEACON->FIRESTORE] Found active session: $sessionId");
      _respondedSessions.add(sessionId);
      _currentDetectedSession = sessionId;

      final subject = activeSession['subject']?.toString() ?? 'Class Session';
      final facultyId = activeSession['facultyId']?.toString() ?? '';
      _sendAttendanceResponse(sessionId, subject, facultyId);
    } catch (e) {
      print("⚠️ Error checking Firestore for active session: $e");
    }
  }

  Future<void> _fetchActiveSessionDetailsAndRespond(
      String sessionId, String className) async {
    String subject = 'Class Session';
    String facultyId = sessionId.split('_')[0];

    try {
      final deptId = studentData?['department']?.toString() ?? '';
      if (deptId.isNotEmpty) {
        final classDoc = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('departments')
            .collection('all_departments')
            .doc(deptId)
            .collection('clasees')
            .doc(className)
            .get();

        if (classDoc.exists) {
          final classData = classDoc.data();
          final activeSession =
              classData?['activeSession'] as Map<String, dynamic>?;
          if (activeSession != null &&
              activeSession['sessionId'] == sessionId) {
            subject = activeSession['subject'] ?? subject;
            facultyId = activeSession['facultyId'] ?? facultyId;
          }
        }
      }
    } catch (e) {
      print("⚠️ Error fetching active session details: $e. Using fallbacks.");
    }

    _sendAttendanceResponse(sessionId, subject, facultyId);
  }

  String? _extractSessionData(ScanResult result) {
    // Try manufacturer data first by scanning all entries
    if (result.advertisementData.manufacturerData.isNotEmpty) {
      for (final entry in result.advertisementData.manufacturerData.entries) {
        try {
          final bytes = entry.value;
          final decoded = utf8.decode(bytes);
          if (decoded.contains('|')) {
            return decoded;
          }
        } catch (e) {
          // Ignore decoding errors for other manufacturer IDs
        }
      }
    }

    // Try service data
    if (result.advertisementData.serviceData.isNotEmpty) {
      for (final entry in result.advertisementData.serviceData.entries) {
        try {
          final bytes = entry.value;
          final decoded = utf8.decode(bytes);
          if (decoded.contains('|')) {
            return decoded;
          }
        } catch (e) {
          // Ignore
        }
      }
    }

    return null;
  }

  Future<bool> _requestBleAdvertisePermissions() async {
    try {
      print(
          "📋 Requesting BLE advertising permissions for student response...");
      final permissions = await [
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ].request();
      return await Permission.bluetoothAdvertise.isGranted;
    } catch (e) {
      print("⚠️ Error requesting BLE advertise permissions: $e");
      return false;
    }
  }

  /// Send attendance by BROADCASTING our ID (Connectionless) to bypass Android pairing popups
  Future<bool> _sendAttendanceViaBLE(
      String sessionId, String subject, String facultyId) async {
    try {
      print("🔌 Attempting connectionless BLE broadcast to faculty...");

      bool hasPermission = await _requestBleAdvertisePermissions();
      if (!hasPermission) {
        print(
            "⚠️ Missing BLE advertise permissions to send offline attendance.");
        return false;
      }

      // Only initialize once - re-initializing crashes on Android
      if (!_blePeripheralInitialized) {
        await BlePeripheral.initialize();
        _blePeripheralInitialized = true;
      }

      // IMPORTANT: Stop scanning before advertising.
      // Many Android chipsets cannot reliably scan + advertise simultaneously.
      // Pausing the scan ensures the STU_ beacon is broadcast cleanly.
      bool wasScanning = _isScanning;
      if (wasScanning) {
        _scanSubscription?.cancel();
        try {
          await FlutterBluePlus.stopScan();
        } catch (_) {}
        // 150ms hardware radio release buffer for MediaTek / older Qualcomm BLE stacks
        await Future.delayed(const Duration(milliseconds: 150));
        if (mounted) setState(() => _isScanning = false);
        print("⏸️ Paused BLE scan to advertise student response.");
      }

      // Check if peripheral advertising is supported on this Android device
      try {
        if (!await BlePeripheral.isSupported()) {
          print("⚠️ BLE peripheral mode not supported on this device. Using Firestore fallback.");
          return false;
        }
      } catch (_) {}

      // 'STU_' prefix + studentId must fit within 27 bytes (31 - 4 byte header)
      final studentIdStr = 'STU_${widget.studentId}';

      print("📡 Broadcasting student ID to faculty over BLE: $studentIdStr");

      await BlePeripheral.startAdvertising(
        services: [], // No service filter — faculty scans all and checks STU_ prefix
        localName: studentIdStr,
      );

      // Broadcast for 8 seconds to give faculty scanner enough time to detect
      await Future.delayed(const Duration(seconds: 8));
      await BlePeripheral.stopAdvertising();

      print("✅ Successfully broadcasted attendance to faculty over BLE!");

      // Restart scanning to remain ready for future sessions
      if (wasScanning && mounted && _isAttendanceActive) {
        await _startBLEAutomatically();
        print("▶️ BLE scan restarted after advertising.");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.bluetooth_connected, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('✅ Attendance sent to faculty via BLE!',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('ID: ${widget.studentId}',
                          style: TextStyle(fontSize: 11)),
                      Text('Subject: $subject', style: TextStyle(fontSize: 11)),
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
      return true;
    } catch (e) {
      print("❌ Connectionless BLE broadcast failed: $e");
      try {
        await BlePeripheral.stopAdvertising();
      } catch (_) {}
      // Try to restart scanning if it was active
      if (_isAttendanceActive && mounted) {
        await _startBLEAutomatically();
      }
      return false;
    }
  }


  // Send attendance response with 3-tier fallback: BLE Direct -> Firebase -> Offline Queue
  Future<void> _sendAttendanceResponse(
      String sessionId, String subject, String facultyId,
      {String? proximityToken}) async {
    try {
      final docId = "${sessionId}_${widget.studentId}";

      // Check to prevent duplicate marking on app restart
      try {
        final existingDoc = await FirebaseFirestore.instance
            .collection('attendance_responses')
            .doc(docId)
            .get();
            
        if (existingDoc.exists) {
          print("✅ Attendance already marked in Firebase. Skipping duplicate popup.");
          _respondedSessions.add(sessionId);
          return;
        }
      } catch (e) {
        // Ignore errors (e.g. offline), proceed with normal flow
      }

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

      String studentClass =
          studentData?['class']?.toString() ?? 'Unknown Class';

      // Tier 1: Trigger connectionless BLE response broadcast (for offline faculty receiver)
      _sendAttendanceViaBLE(sessionId, subject, facultyId);

      print("📝 Preparing online Firebase attendance response:");
      print("   Student ID: ${widget.studentId}");
      print("   Student Name: $studentName");
      print("   Student Class: $studentClass");
      print("   Session ID: $sessionId");
      print("   Subject: $subject");
      if (proximityToken != null) print("   Proximity Token: $proximityToken");

      await FirebaseFirestore.instance
          .collection('attendance_responses')
          .doc(docId)
          .set({
        'sessionId': sessionId,
        'studentId': widget.studentId,
        'studentName': studentName, // Properly retrieved student name
        'studentClass': studentClass, // Add class for better identification
        'timestamp': FieldValue.serverTimestamp(),
        'deviceId':
            '${widget.studentId}_${DateTime.now().millisecondsSinceEpoch}',
        'subject': subject,
        'facultyId': facultyId,
        'responseTime':
            DateTime.now().toIso8601String(), // Add local timestamp as backup
        'status': 'present', // Explicitly mark as present
        if (proximityToken != null) 'proximityToken': proximityToken,
      }, SetOptions(merge: true));

      print("✅ Attendance response sent successfully to Firebase!");
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
                      Text('Subject: $subject', style: TextStyle(fontSize: 11)),
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
      print(
          "❌ Error sending attendance response online: $e. Using offline queue fallback.");

      // Tier 3: Offline Queue fallback when both BLE and Firebase fail
      String studentName =
          studentData?['name']?.toString() ?? 'Student_${widget.studentId}';
      String studentClass =
          studentData?['class']?.toString() ?? 'Unknown Class';

      await OfflineAttendanceQueue.queueAttendance(
        sessionId: sessionId,
        studentId: widget.studentId,
        studentName: studentName,
        studentClass: studentClass,
        subject: subject,
        facultyId: facultyId,
        timestamp: DateTime.now().toIso8601String(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.offline_pin, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📶 Attendance queued offline!',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                          'Will sync automatically when internet is available.',
                          style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
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
