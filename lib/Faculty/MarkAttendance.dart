import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:geolocator/geolocator.dart';

// Custom Color Palette
const Color kPrimary = Color(0xFFFF7043);
const Color kBackground = Color(0xFFF9F9F9);
const Color kShadow = Color(0xFFFFFFFF);


class MarkAttendance extends StatefulWidget {
  final String facultyId;
  const MarkAttendance({Key? key, required this.facultyId}) : super(key: key);

  @override
  State<MarkAttendance> createState() => _MarkAttendanceState();
}

class _MarkAttendanceState extends State<MarkAttendance> {
  List<String> classes = [];
  bool isLoading = true;
  String error = '';
  String facultyName = '';
  String departmentId = '';

  @override
  void initState() {
    super.initState();
    _fetchFacultyDetails();
  }

  Future<void> _fetchFacultyDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('faculties')
          .collection('all_faculties')
          .doc(widget.facultyId)
          .get();
      if (!doc.exists || doc.data() == null) {
        setState(() {
          error = 'Faculty not found';
          isLoading = false;
        });
        return;
      }
      final data = doc.data()!;
      setState(() {
        facultyName = data['name'] ?? 'Unknown Faculty';
        departmentId = data['department'] ?? '';
        classes = List<String>.from(data['classes'] ?? []);
        error = '';
      });
    } catch (e) {
      setState(() {
        error = 'Error loading faculty details: $e';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _openClassAttendance(String className) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassAttendanceScreen(
          facultyId: widget.facultyId,
          departmentId: departmentId,
          className: className,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimary,
        title: Text(
          'ATTENDANCE REGISTER',
          style: TextStyle(color: Colors.white, fontSize: 20),
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(child: Text(error))
          : classes.isEmpty
          ? const Center(child: Text('No classes assigned'))
          : ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: classes.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, idx) {
          final className = classes[idx];
          return Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 2,
            child: ListTile(
              leading: const Icon(Icons.class_, color: Color(0xFF36454F)),
              title: Text(
                className,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              trailing: const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF36454F)),
              onTap: () => _openClassAttendance(className),
            ),
          );
        },
      ),
    );
  }
}

class ClassAttendanceScreen extends StatefulWidget {
  final String facultyId;
  final String departmentId;
  final String className;

  const ClassAttendanceScreen({
    Key? key,
    required this.facultyId,
    required this.departmentId,
    required this.className,
  }) : super(key: key);

  @override
  State<ClassAttendanceScreen> createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen> {
  // BLE Peripheral Advertising
  final FlutterBlePeripheral _blePeripheral = FlutterBlePeripheral();

  bool isAdvertising = false;
  String? currentSessionId;
  String? advertisingSubject;
  Set<String> detectedStudentIds = {};
  Timer? _liveUpdateTimer;
  List<Map<String, dynamic>> liveDetectedStudents = [];

  final AdvertiseSettings advertiseSettings = AdvertiseSettings(
    advertiseMode: AdvertiseMode.advertiseModeBalanced,
    txPowerLevel: AdvertiseTxPower.advertiseTxPowerMedium,
    connectable: false,
    timeout: 0,
  );

  bool isLoading = true;
  bool subjectsLoading = false;
  bool isSaving = false;
  bool isLoadingAttendance = false;
  String error = '';
  List<Map<String, dynamic>> students = [];
  Map<String, bool> attendance = {};
  List<String> subjects = [];
  String? selectedSubject;
  final List<String> semesters = [
    'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'
  ];
  String? selectedSemester;
  List<Map<String, dynamic>> facultySubjectMappings = [];
  DateTime selectedDate = DateTime.now();
  String searchQuery = '';
  String? selectedHour;
  String? selectedEndHour;
  bool isContinuousMode = false;
  final List<String> hours = ['1', '2', '3', '4', '5', '6', '7', '8'];

  @override
  void initState() {
    super.initState();
    _initData();
  }
  StreamSubscription<QuerySnapshot>? _responseSubscription;

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _liveUpdateTimer?.cancel();
    stopAdvertising();
    super.dispose();
  }

  // BLE Advertising Methods with Live Updates
  Future<void> startAdvertising() async {
    if (isAdvertising || selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a subject first!')),
      );
      return;
    }

    // Generate short session ID: facultyId + 6 char random alphanumeric suffix
    final randomSuffix = List.generate(6, (index) {
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      return chars[Random().nextInt(chars.length)];
    }).join();
    final sessionId = '${widget.facultyId}_$randomSuffix';

    print("🚀 Starting broadcast with Session ID: $sessionId");

    // Get faculty GPS location for proximity verification with robust fallbacks
    double? facLat;
    double? facLng;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Request enabling location services
        print("⚠️ Location services are disabled on faculty device.");
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.medium, // Medium accuracy is faster and sufficient for classroom proximity
          ).timeout(const Duration(seconds: 4));
          facLat = pos.latitude;
          facLng = pos.longitude;
        } catch (e) {
          print("⚠️ getCurrentPosition failed or timed out: $e. Trying last known position...");
          final lastPos = await Geolocator.getLastKnownPosition();
          if (lastPos != null) {
            facLat = lastPos.latitude;
            facLng = lastPos.longitude;
          }
        }
      }
      print("📍 Faculty location: $facLat, $facLng");
    } catch (e) {
      print("⚠️ Could not get faculty location: $e");
    }

    // Write active session metadata to the class document in Firestore
    try {
      await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(widget.departmentId)
          .collection('clasees')
          .doc(widget.className)
          .update({
        'activeSession': {
          'sessionId': sessionId,
          'subject': selectedSubject,
          'facultyId': widget.facultyId,
          'startedAt': DateTime.now().toIso8601String(),
          if (facLat != null) 'lat': facLat,
          if (facLng != null) 'lng': facLng,
        }
      });
      print("✅ Active session metadata written to Firestore class document.");
    } catch (e) {
      print("⚠️ Failed to write active session metadata: $e");
    }

    // Broadcast with minimal BLE payload for maximum device compatibility.
    // Session data is already in Firestore — BLE is just a proximity beacon.
    final advertiseData = AdvertiseData(
      serviceUuid: "bf27730d-860a-4e09-889c-2d8b6a9e0fe7",
      manufacturerId: 1234,
      manufacturerData: Uint8List.fromList([0x01]), // 1-byte beacon flag
    );

    try {
      await _blePeripheral.start(
        advertiseData: advertiseData,
        advertiseSettings: advertiseSettings,
      );

      setState(() {
        isAdvertising = true;
        currentSessionId = sessionId;
        advertisingSubject = selectedSubject;
        detectedStudentIds.clear();
        liveDetectedStudents.clear();
      });

      // CRITICAL: Start the real-time listener IMMEDIATELY after setting state
      print("🎯 Starting real-time Firestore listener...");
      startLiveResponseMonitoring();

      // Show broadcasting popup
      _showLiveDetectionDialog();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Broadcasting started for $selectedSubject!'),
          backgroundColor: Colors.green,
        ),
      );

      print("✅ Broadcasting active - Session: $sessionId");

    } catch (e) {
      print("❌ Error starting BLE advertising: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start broadcasting: $e')),
      );
    }
  }

  void _processResponseSnapshot(QuerySnapshot snapshot) {
    if (!mounted || currentSessionId == null) {
      print("⚠️ Skipping processing - not mounted or no session");
      return;
    }

    List<Map<String, dynamic>> newDetectedStudents = [];
    Set<String> newDetectedIds = {};
    bool hasNewStudents = false;

    print("🔄 Processing ${snapshot.docs.length} responses for session: $currentSessionId");

    for (var doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final studentId = data['studentId'] as String?;
        final studentName = data['studentName'] as String?;
        final timestamp = data['timestamp'] as Timestamp?;
        final sessionId = data['sessionId'] as String?;

        // Verify this response is for current session
        if (sessionId != currentSessionId) {
          print("⚠️ Skipping response for different session: $sessionId");
          continue;
        }

        if (studentId == null) {
          print("⚠️ Skipping response with null studentId");
          continue;
        }

        print("📋 Processing response:");
        print("   Student ID: $studentId");
        print("   Student Name: $studentName");
        print("   Session Match: ${sessionId == currentSessionId}");

        newDetectedIds.add(studentId);

        // Check if this is a new detection
        if (!detectedStudentIds.contains(studentId)) {
          hasNewStudents = true;
          print("🆕 NEW STUDENT DETECTED: $studentId - $studentName");

          // Get student name with better fallback logic
          String displayName = studentName ?? 'Unknown';
          if (displayName.isEmpty || displayName == 'Unknown Student') {
            final studentData = students.firstWhere(
                  (s) => s['id'] == studentId,
              orElse: () => <String, dynamic>{},
            );
            if (studentData.isNotEmpty) {
              displayName = studentData['name'] ?? studentData['student_name'] ?? studentId;
            } else {
              displayName = studentId;
            }
          }

          print("👤 Final display name: $displayName");

          newDetectedStudents.add({
            'id': studentId,
            'name': displayName,
            'timestamp': timestamp?.toDate() ?? DateTime.now(),
            'isNew': true,
          });

          // Mark student as present in main attendance
          _markStudentPresent(studentId);
        }
      } catch (e) {
        print("❌ Error processing response document: $e");
      }
    }

    // Update state with all changes at once
    if (hasNewStudents || detectedStudentIds.length != newDetectedIds.length) {
      setState(() {
        // Update detected student IDs
        detectedStudentIds.clear();
        detectedStudentIds.addAll(newDetectedIds);

        // Add new students to live list
        for (var student in newDetectedStudents) {
          bool exists = liveDetectedStudents.any((s) => s['id'] == student['id']);
          if (!exists) {
            liveDetectedStudents.insert(0, student);
          }
        }

        // Mark older entries as not new
        for (var student in liveDetectedStudents) {
          if (student['isNew'] == true) {
            final studentTimestamp = student['timestamp'] as DateTime;
            if (DateTime.now().difference(studentTimestamp).inSeconds > 5) {
              student['isNew'] = false;
            }
          }
        }

        // Force refresh of attendance map
        attendance = Map<String, bool>.from(attendance);
      });

      print("✅ State updated: ${detectedStudentIds.length} total detected, ${newDetectedStudents.length} new");
      print("   Live detected students: ${liveDetectedStudents.length}");
    }
  }

  Future<void> stopAdvertising() async {
    if (!isAdvertising) return;

    try {
      await _blePeripheral.stop();
      _liveUpdateTimer?.cancel();
      _responseSubscription?.cancel(); // Clean up Firestore listener

      // Clear activeSession metadata from Firestore class document
      try {
        if (currentSessionId != null) {
          await FirebaseFirestore.instance
              .collection('colleges')
              .doc('departments')
              .collection('all_departments')
              .doc(widget.departmentId)
              .collection('clasees')
              .doc(widget.className)
              .update({
            'activeSession': FieldValue.delete(),
          });
          print("✅ Active session metadata removed from Firestore.");
        }
      } catch (e) {
        print("⚠️ Failed to remove active session metadata: $e");
      }

      setState(() {
        isAdvertising = false;
        currentSessionId = null;
        advertisingSubject = null;
        liveDetectedStudents.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Broadcasting stopped"),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      print("❌ Error stopping BLE advertising: $e");
    }
  }

  void startLiveResponseMonitoring() {
    // Cancel existing subscriptions
    _responseSubscription?.cancel();
    _liveUpdateTimer?.cancel();

    if (currentSessionId == null) {
      print("❌ Cannot start monitoring - currentSessionId is null");
      return;
    }

    print("🎯 Starting REAL-TIME listener for session: $currentSessionId");

    // Set up real-time Firestore listener
    _responseSubscription = FirebaseFirestore.instance
        .collection('attendance_responses')
        .where('sessionId', isEqualTo: currentSessionId)
        .snapshots()  // Remove orderBy to avoid index issues
        .listen(
          (snapshot) {
        print("📡 Firestore listener triggered:");
        print("   Found ${snapshot.docs.length} total responses");
        print("   Changes: ${snapshot.docChanges.length}");

        // Process each document change
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            final data = change.doc.data() as Map<String, dynamic>?;
            if (data != null) {
              print("📋 NEW response detected:");
              print("   Student ID: ${data['studentId']}");
              print("   Student Name: ${data['studentName']}");
              print("   Session: ${data['sessionId']}");
            }
          }
        }

        _processResponseSnapshot(snapshot);
      },
      onError: (error) {
        print("❌ Firestore listener error: $error");

        // Retry mechanism
        Future.delayed(Duration(seconds: 2), () {
          if (mounted && isAdvertising && currentSessionId != null) {
            print("🔄 Retrying Firestore listener...");
            startLiveResponseMonitoring();
          }
        });
      },
    );

    print("✅ Real-time listener established for session: $currentSessionId");

    // Add a backup polling mechanism for extra safety
    _liveUpdateTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      if (!isAdvertising || currentSessionId == null) {
        timer.cancel();
        return;
      }
      print("🔄 Backup check - Current detected: ${detectedStudentIds.length}");
    });
  }

  // FIXED: Now properly retrieves and displays student names AND updates UI
  Future<void> _fetchLiveStudentResponses() async {
    if (currentSessionId == null) return;

    try {
      print("🔍 Fetching live responses for session: $currentSessionId");

      final responsesSnapshot = await FirebaseFirestore.instance
          .collection('attendance_responses')
          .where('sessionId', isEqualTo: currentSessionId)
          .orderBy('timestamp', descending: true)
          .get();

      print("📊 Found ${responsesSnapshot.docs.length} responses in Firestore");

      List<Map<String, dynamic>> newDetectedStudents = [];
      Set<String> newDetectedIds = {};
      bool hasNewStudents = false;

      for (var doc in responsesSnapshot.docs) {
        final data = doc.data();
        final studentId = data['studentId'] as String?;
        final studentName = data['studentName'] as String?;
        final timestamp = data['timestamp'] as Timestamp?;

        if (studentId == null) continue;

        print("📝 Processing response: $studentId -> $studentName");

        newDetectedIds.add(studentId);

        // Check if this is a new detection
        if (!detectedStudentIds.contains(studentId)) {
          hasNewStudents = true;

          // Get student name with better fallback logic
          String displayName = studentName ?? 'Unknown';

          if (displayName.isEmpty || displayName == 'Unknown' || displayName == 'Unknown Student') {
            // Try to find student in the main students list
            final studentData = students.firstWhere(
                  (s) => s['id'] == studentId,
              orElse: () => <String, dynamic>{},
            );

            if (studentData.isNotEmpty) {
              displayName = studentData['name'] ?? studentData['student_name'] ?? studentId;
            } else {
              displayName = studentId; // Use ID as fallback
            }
          }

          print("✅ NEW STUDENT DETECTED: $studentId -> $displayName");

          newDetectedStudents.add({
            'id': studentId,
            'name': displayName,
            'timestamp': timestamp?.toDate() ?? DateTime.now(),
            'isNew': true,
          });

          // CRITICAL: Mark student as present in main attendance
          await _markStudentPresent(studentId);
        }
      }

      // Update state with all changes at once
      if (hasNewStudents || newDetectedIds.isNotEmpty) {
        setState(() {
          // Update detected student IDs
          detectedStudentIds.addAll(newDetectedIds);

          // Add new students to live list
          for (var student in newDetectedStudents) {
            // Prevent duplicates
            bool exists = liveDetectedStudents.any((s) => s['id'] == student['id']);
            if (!exists) {
              liveDetectedStudents.insert(0, student);
            }
          }

          // Mark older entries as not new
          for (var student in liveDetectedStudents) {
            if (student['isNew'] == true) {
              final studentTimestamp = student['timestamp'] as DateTime;
              if (DateTime.now().difference(studentTimestamp).inSeconds > 5) {
                student['isNew'] = false;
              }
            }
          }

          // Force refresh of attendance map
          attendance = Map<String, bool>.from(attendance);
        });

        print("🔄 State updated: ${detectedStudentIds.length} total detected, ${newDetectedStudents.length} new");
      }

    } catch (e) {
      print('❌ Error fetching live student responses: $e');
    }
  }

  String _getStudentName(String studentId) {
    final student = students.firstWhere(
            (s) => s['id'] == studentId,
        orElse: () => {'name': 'Unknown Student'}
    );
    return student['name'] ?? 'Unknown Student';
  }

  Future<void> _markStudentPresent(String studentId) async {
    try {
      print("✅ Marking student present: $studentId");

      // First, update local state immediately
      if (mounted) {
        setState(() {
          attendance[studentId] = true;
          print("📱 Local state updated: $studentId marked present");
        });
      }

      // Then update Firestore (optional - for persistence)
      String classId = students.firstWhere(
            (student) => student['id'] == studentId,
        orElse: () => {'class': widget.className}, // Use widget.className as fallback
      )['class'] ?? widget.className;

      print("📊 Updating Firestore for student $studentId in class $classId");

    } catch (e) {
      print("❌ Error marking student present: $e");
    }
  }


  // IMPROVED METHOD: Merge BLE detected students with attendance UI
  Future<void> _mergeBLEDetectedStudents() async {
    if (currentSessionId == null) return;

    try {
      print("🔍 Checking for BLE detected students for session: $currentSessionId");

      final snapshot = await FirebaseFirestore.instance
          .collection('attendance_responses')
          .where('sessionId', isEqualTo: currentSessionId)
          .get();

      int detectedCount = 0;
      bool uiNeedsUpdate = false;
      List<String> detectedStudentNames = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        String? studentId = data['studentId'];
        String? studentName = data['studentName'];

        if (studentId != null && attendance.containsKey(studentId)) {
          // Update both attendance map and detected set
          attendance[studentId] = true; // Mark as present
          detectedStudentIds.add(studentId);

          // Get proper student name
          final properName = studentName ?? _getStudentName(studentId);
          detectedStudentNames.add(properName);

          detectedCount++;
          uiNeedsUpdate = true;

          print("✅ Marked student $studentId ($properName) as present via BLE");
        }
      }

      // CRITICAL: Update UI with single setState call
      if (uiNeedsUpdate) {
        setState(() {
          // Force rebuild of the entire attendance list
          attendance = Map.from(attendance); // Create new map reference to trigger rebuild
        });

        print("🎯 Total BLE detected students: $detectedCount");
        print("👥 Detected students: ${detectedStudentNames.join(', ')}");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ $detectedCount students marked via BLE detection'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

    } catch (e) {
      print("❌ Error merging BLE detected students: $e");
    }
  }

  // Live Detection Dialog
  void _showLiveDetectionDialog() {
    Timer? dialogTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // Cancel previous timer
          dialogTimer?.cancel();

          // Start new timer with more frequent updates
          dialogTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
            if (!isAdvertising || !mounted) {
              timer.cancel();
              return;
            }
            if (mounted) {
              setModalState(() {
                // Force refresh of modal content
              });
            }
          });

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Your existing dialog content...
                Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.8, end: 1.2),
                        duration: Duration(milliseconds: 1000),
                        builder: (context, double scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Icon(Icons.wifi_tethering, color: Colors.white, size: 28),
                          );
                        },
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Broadcasting Active',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Subject: ${advertisingSubject ?? 'Unknown'}',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            Text(
                              '${detectedStudentIds.length} students detected',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.stop_circle, color: Colors.white, size: 32),
                        onPressed: () {
                          dialogTimer?.cancel();
                          stopAdvertising();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),

                // Stats section
                Container(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _buildStatCard('Total', students.length.toString(), Icons.people, Colors.blue),
                      SizedBox(width: 10),
                      _buildStatCard('Present', detectedStudentIds.length.toString(), Icons.check_circle, Colors.green),
                      SizedBox(width: 10),
                      _buildStatCard('Absent', (students.length - detectedStudentIds.length).toString(), Icons.cancel, Colors.red),
                    ],
                  ),
                ),

                // Live students list
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.bluetooth, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Live Student Signals (${liveDetectedStudents.length})',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Divider(),
                      Expanded(
                        child: liveDetectedStudents.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Waiting for student signals...',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Students should open their app for auto-detection',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          itemCount: liveDetectedStudents.length,
                          itemBuilder: (context, index) {
                            final student = liveDetectedStudents[index];
                            final isNew = student['isNew'] == true;
                            final timestamp = student['timestamp'] as DateTime;

                            return AnimatedContainer(
                              duration: Duration(milliseconds: 500),
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: isNew ? Colors.green.shade50 : Colors.blue.shade50,
                                border: Border.all(
                                  color: isNew ? Colors.green : Colors.blue.shade200,
                                  width: isNew ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isNew ? Colors.green : Colors.blue,
                                  child: Text(
                                    student['name'].toString().isNotEmpty
                                        ? student['name'].toString().substring(0, 1).toUpperCase()
                                        : '?',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(
                                  student['name'] ?? 'Unknown Student',
                                  style: TextStyle(
                                    fontWeight: isNew ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('ID: ${student['id']}'),
                                    Text(
                                      'Detected: ${DateFormat('HH:mm:ss').format(timestamp)}',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isNew) ...[
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'NEW',
                                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                    ],
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.green,
                                      size: 24,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Bottom section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Session ID:', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          Text(currentSessionId?.substring(currentSessionId!.length - 8) ?? 'Unknown',
                              style: TextStyle(fontSize: 10, fontFamily: 'monospace')),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          dialogTimer?.cancel();
                          stopAdvertising();
                          Navigator.pop(context);
                        },
                        icon: Icon(Icons.stop),
                        label: Text('Stop Broadcasting'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      dialogTimer?.cancel(); // Clean up timer when dialog closes
    });
  }


  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  // All your existing methods remain the same...
  Future<void> _initData() async {
    try {
      selectedSemester = semesters.first;
      selectedHour = hours.first;
      await Future.wait([
        _fetchStudentsForClass(),
        _loadSemesterData(selectedSemester!),
      ]);
      await _loadExistingAttendance();
    } catch (e) {
      setState(() {
        error = 'Initialization failed: $e';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadSemesterData(String semester) async {
    await _fetchSubjectsForSemester(semester);
    await _fetchFacultySubjectMapping(semester);
    setState(() {
      selectedSubject = getSubjectsForThisFaculty().isNotEmpty
          ? getSubjectsForThisFaculty().first
          : null;
    });
  }

  Future<void> _fetchSubjectsForSemester(String semester) async {
    setState(() {
      subjects = [];
      subjectsLoading = true;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(widget.departmentId)
          .collection('clasees')
          .doc(widget.className)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        if (data.containsKey(semester)) {
          subjects = List<String>.from(data[semester] ?? []);
          print('✅ Fetched ${subjects.length} subjects for semester $semester: $subjects');
        } else {
          subjects = [];
          print('❌ No subjects found for semester: $semester');
        }
      } else {
        subjects = [];
        print('❌ No class document found');
      }
    } catch (e) {
      print('❌ Error fetching subjects: $e');
      setState(() {
        error = 'Error loading subjects: $e';
      });
    } finally {
      setState(() => subjectsLoading = false);
    }
  }

  Future<void> _fetchFacultySubjectMapping(String semester) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(widget.departmentId)
          .collection('clasees')
          .doc(widget.className)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};

        if (data.containsKey('faculty') && data['faculty'] != null) {
          final facultyData = data['faculty'] as Map<String, dynamic>;

          if (facultyData.containsKey(semester)) {
            facultySubjectMappings = List<Map<String, dynamic>>.from(
              facultyData[semester] ?? [],
            );
            print('✅ Fetched ${facultySubjectMappings.length} faculty mappings');
          } else {
            facultySubjectMappings = [];
            print('❌ No faculty mappings for semester: $semester');
          }
        } else {
          facultySubjectMappings = [];
          print('❌ No faculty field found');
        }
      } else {
        facultySubjectMappings = [];
      }
    } catch (e) {
      print('❌ Error fetching faculty-subject mapping: $e');
      facultySubjectMappings = [];
    }
  }

  Future<void> _fetchStudentsForClass() async {
    try {
      final query = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .where('class', isEqualTo: widget.className)
          .get();
      students = query.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'name': data['name'] ?? 'Unknown',
          ...data,
        };
      }).toList();
      attendance = {for (var s in students) s['id']: false};
      print('✅ Fetched ${students.length} students');
    } catch (e) {
      setState(() {
        error = 'Error fetching students: $e';
      });
    }
  }

  // UPDATED: Now includes BLE merge after loading attendance
  Future<void> _loadExistingAttendance() async {
    if (selectedSubject == null || selectedHour == null || students.isEmpty || selectedSemester == null) return;
    setState(() => isLoadingAttendance = true);

    try {
      final dateKey = DateFormat('dd-MM-yyyy').format(selectedDate);
      List<int> hourIndices = [];

      if (isContinuousMode && selectedEndHour != null) {
        final startHour = int.tryParse(selectedHour!) ?? 1;
        final endHour = int.tryParse(selectedEndHour!) ?? 1;
        final start = startHour <= endHour ? startHour : endHour;
        final end = startHour <= endHour ? endHour : startHour;
        for (int i = start; i <= end; i++) {
          hourIndices.add(i - 1);
        }
      } else {
        hourIndices = [(int.tryParse(selectedHour!) ?? 1) - 1];
      }

      attendance = {for (var s in students) s['id']: false};

      const batchSize = 10;
      final batches = <List<Map<String, dynamic>>>[];
      for (int i = 0; i < students.length; i += batchSize) {
        final end = (i + batchSize < students.length) ? i + batchSize : students.length;
        batches.add(students.sublist(i, end));
      }

      final futures = batches.map((batch) => _loadAttendanceForBatch(batch, dateKey, hourIndices));
      await Future.wait(futures).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Attendance loading timed out');
          return <void>[];
        },
      );

      // CRITICAL: Merge BLE detected students after loading standard attendance
      await _mergeBLEDetectedStudents();

    } catch (e) {
      print('Error loading existing attendance: $e');
    } finally {
      setState(() => isLoadingAttendance = false);
    }
  }

  Future<void> _loadAttendanceForBatch(
      List<Map<String, dynamic>> batch,
      String dateKey,
      List<int> hourIndices,
      ) async {
    final futures = batch.map((student) async {
      final studentId = student['id'];
      try {
        final attendanceRef = FirebaseFirestore.instance
            .collection('colleges')
            .doc('students')
            .collection('all_students')
            .doc(studentId)
            .collection('attendance')
            .doc(selectedSemester!);
        final docSnap = await attendanceRef.get();
        final data = docSnap.data();
        if (data == null || data[dateKey] == null) return;
        final dailyAttendance = Map<String, dynamic>.from(data[dateKey]);
        bool isPresentInAllHours = true;
        for (final hourIdx in hourIndices) {
          final hourEntry = dailyAttendance["$hourIdx"];
          if (hourEntry != null && hourEntry is Map && hourEntry.containsKey(selectedSubject!)) {
            final status = hourEntry[selectedSubject!];
            if (status != "P") {
              isPresentInAllHours = false;
              break;
            }
          } else {
            isPresentInAllHours = false;
            break;
          }
        }
        attendance[studentId] = isPresentInAllHours;
      } catch (e) {
        print('Error loading attendance for student $studentId: $e');
      }
    });
    await Future.wait(futures);
  }

  void _onSelectionChanged() {
    if (selectedSubject != null && selectedHour != null && students.isNotEmpty && selectedSemester != null) {
      if (isContinuousMode && selectedEndHour != null) {
        final startHour = int.tryParse(selectedHour!) ?? 1;
        final endHour = int.tryParse(selectedEndHour!) ?? 1;
        if (endHour < startHour) {
          setState(() {
            selectedEndHour = selectedHour;
          });
        }
      }
      _loadExistingAttendance();
    }
  }

  List<String> getAvailableEndHours() {
    if (selectedHour == null) return [];
    final startHourIndex = int.tryParse(selectedHour!) ?? 1;
    return hours.where((h) => (int.tryParse(h) ?? 1) >= startHourIndex).toList();
  }

  List<String> getSubjectsForThisFaculty() {
    return facultySubjectMappings
        .where((m) => m['facultyId'] == widget.facultyId)
        .map((m) => m['subject'] as String)
        .toList();
  }

  Future<void> _updateAttendancePercentagesFromHistory() async {
    int presentCount = 0;
    int absentCount = 0;
    int onDutyCount = 0;
    int totalMarks = 0;

    for (var student in students) {
      final attendanceRef = FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(student['id'])
          .collection('attendance')
          .doc(selectedSemester!);

      final docSnap = await attendanceRef.get();
      final data = docSnap.data() ?? {};

      data.forEach((key, value) {
        if (key == 'P' || key == 'A' || key == 'OD') return;
        if (value is Map<String, dynamic>) {
          value.forEach((hour, hourEntry) {
            if (hourEntry is Map<String, dynamic>) {
              hourEntry.forEach((subject, status) {
                totalMarks++;
                if (status == 'P') presentCount++;
                else if (status == 'A') absentCount++;
                else if (status == 'OD') onDutyCount++;
              });
            }
          });
        }
      });
    }

    double presentPercentage = totalMarks > 0 ? (presentCount / totalMarks) * 100 : 0;
    double absentPercentage = totalMarks > 0 ? (absentCount / totalMarks) * 100 : 0;
    double onDutyPercentage = totalMarks > 0 ? (onDutyCount / totalMarks) * 100 : 0;

    for (var student in students) {
      final attendanceRef = FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(student['id'])
          .collection('attendance')
          .doc(selectedSemester!);

      await attendanceRef.set({
        'P': presentPercentage,
        'A': absentPercentage,
        'OD': onDutyPercentage,
      }, SetOptions(merge: true));
    }
  }

  Future<void> _saveAttendance() async {
    if (students.isEmpty ||
        selectedSubject == null ||
        selectedSemester == null ||
        selectedHour == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select semester, subject, hour and have students')),
      );
      return;
    }
    setState(() => isSaving = true);
    try {
      final dateKey = DateFormat('dd-MM-yyyy').format(selectedDate);
      final subject = selectedSubject!;
      List<int> hourIndices = [];
      if (isContinuousMode && selectedEndHour != null) {
        final startHour = int.tryParse(selectedHour!) ?? 1;
        final endHour = int.tryParse(selectedEndHour!) ?? 1;
        final start = startHour <= endHour ? startHour : endHour;
        final end = startHour <= endHour ? endHour : startHour;
        for (int i = start; i <= end; i++) {
          hourIndices.add(i - 1);
        }
      } else {
        hourIndices = [(int.tryParse(selectedHour!) ?? 1) - 1];
      }
      const batchSize = 10;
      final batches = <List<Map<String, dynamic>>>[];
      for (int i = 0; i < students.length; i += batchSize) {
        final end = (i + batchSize < students.length) ? i + batchSize : students.length;
        batches.add(students.sublist(i, end));
      }
      final futures = batches.map((batch) => _saveAttendanceForBatch(batch, dateKey, hourIndices, subject));
      await Future.wait(futures);
      await _updateAttendancePercentagesFromHistory();
      final hourText = isContinuousMode && selectedEndHour != null
          ? 'Hours $selectedHour-$selectedEndHour'
          : 'Hour $selectedHour';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance saved successfully for $hourText')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      setState(() => isSaving = false);
    }
  }

  Future<void> _saveAttendanceForBatch(
      List<Map<String, dynamic>> batch,
      String dateKey,
      List<int> hourIndices,
      String subject,
      ) async {
    final futures = batch.map((s) async {
      final studentId = s['id'];
      final isPresent = attendance[studentId] ?? false;
      final status = isPresent ? "P" : "A";
      try {
        final attendanceRef = FirebaseFirestore.instance
            .collection('colleges')
            .doc('students')
            .collection('all_students')
            .doc(studentId)
            .collection('attendance')
            .doc(selectedSemester!);

        final docSnap = await attendanceRef.get();
        final data = docSnap.data() ?? {};
        Map<String, dynamic> attendanceDay = {};
        if (data[dateKey] != null) {
          attendanceDay = Map<String, dynamic>.from(data[dateKey]);
        }
        for (final hourIdx in hourIndices) {
          attendanceDay["$hourIdx"] = {subject: status};
        }
        await attendanceRef.set({dateKey: attendanceDay}, SetOptions(merge: true));
      } catch (e) {
        print('Error saving attendance for student $studentId: $e');
        rethrow;
      }
    });
    await Future.wait(futures);
  }

  void _markAll(bool present) {
    setState(() {
      for (var key in attendance.keys) {
        attendance[key] = present;
      }
    });
  }

  List<DateTime> getDateList() {
    final now = DateTime.now();
    return List.generate(4, (i) => now.subtract(Duration(days: 3 - i)));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          backgroundColor: kPrimary,
          elevation: 0,
          title: const Text(
            'ATTENDANCE REGISTER',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          leading: const BackButton(color: Colors.white),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
                strokeWidth: 3,
              ),
              const SizedBox(height: 20), // Fixed: Added missing height value
              const Text(
                'Loading class data...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Please wait',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black38,
                ),
              ),
            ],
          ),
        ),

      );
    }
    if (error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Attendance — ${widget.className}'),
          backgroundColor: kPrimary,
        ),
        body: Center(child: Text(error)),
      );
    }
    final filteredStudents = students
        .where((s) => s['name'].toLowerCase().contains(searchQuery.toLowerCase()) || s['id'].toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimary,
        elevation: 0,
        title: const Text('MARK ATTENDANCE', style: TextStyle(color: Colors.white, fontSize: 24),),
        actions: [
          // BLE Broadcasting Button
          IconButton(
            icon: Icon(
              isAdvertising ? Icons.stop_circle : Icons.wifi_tethering,
              color: isAdvertising ? Colors.red : Colors.white,
              size: 28,
            ),
            onPressed: () {
              if (isAdvertising) {
                stopAdvertising();
              } else {
                startAdvertising();
              }
            },
            tooltip: isAdvertising ? 'Stop Broadcasting' : 'Start Broadcasting',
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: isSaving ? null : _saveAttendance,
          ),
        ],
        leading: const BackButton(color: Colors.white),
      ),
      body: Column(
        children: [
          // Broadcasting Status Banner
          if (isAdvertising)
            Container(
              width: double.infinity,
              color: Colors.green.shade100,
              padding: EdgeInsets.all(8),
              child: GestureDetector(
                onTap: _showLiveDetectionDialog,
                child: Row(
                  children: [
                    Icon(Icons.wifi_tethering, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Broadcasting ${advertisingSubject ?? 'Unknown'} • ${detectedStudentIds.length} students detected • Tap to view live',
                        style: TextStyle(color: Colors.green.shade800, fontSize: 12),
                      ),
                    ),
                    TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0.5, end: 1.0),
                      duration: Duration(milliseconds: 1000),
                      builder: (context, double value, child) {
                        return Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(value),
                            shape: BoxShape.circle,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Top Dropdowns: Semester and Subject
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSemester,
                        isExpanded: true,
                        hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('Select Sem'),),
                        onChanged: (v) async {
                          if (v != null) {
                            setState(() => selectedSemester = v);
                            await _loadSemesterData(v);
                            _onSelectionChanged();
                          }
                        },
                        items: semesters.map((e) =>
                            DropdownMenuItem(
                              value: e,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(e),
                              ),
                            )).toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSubject,
                        isExpanded: true,
                        hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('Select Subject'),),
                        onChanged: (v) {
                          setState(() => selectedSubject = v);
                          _onSelectionChanged();
                        },
                        items: getSubjectsForThisFaculty().map((e) =>
                            DropdownMenuItem(
                              value: e,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(e),
                              ),
                            )).toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Present and Absent Count Row (instead of Date Picker)
          Builder(
            builder: (context) {
              final presentCount = students.where((s) => attendance[s['id']] == true).length;
              final absentCount = students.length - presentCount;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$presentCount',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'PRESENT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.green.shade700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$absentCount',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ABSENT',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade700,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }
          ),

          // Search & Hour Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: kShadow, blurRadius: 3, offset: Offset(1, 2)),],
                        ),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: "Search students",
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          onChanged: (val) => setState(() => searchQuery = val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isContinuousMode ? kPrimary : Colors.grey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              isContinuousMode = !isContinuousMode;
                              if (!isContinuousMode) {
                                selectedEndHour = null;
                              } else {
                                selectedEndHour = selectedHour;
                              }
                            });
                            _onSelectionChanged();
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Center(
                            child: Text(
                              isContinuousMode ? 'Multiple Hours' : 'Single Hour',
                              style: TextStyle(color: isContinuousMode ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF222F3E),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedHour,
                            isExpanded: true,
                            dropdownColor: Color(0xFF222F3E),
                            hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('Start Hour', style: TextStyle(color: Colors.white),),),
                            onChanged: (v) {
                              setState(() {
                                selectedHour = v;
                                if (isContinuousMode && selectedEndHour != null) {
                                  final startHour = int.tryParse(v!) ?? 1;
                                  final endHour = int.tryParse(selectedEndHour!) ?? 1;
                                  if (endHour < startHour) {
                                    selectedEndHour = v;
                                  }
                                }
                              });
                              _onSelectionChanged();
                            },
                            style: const TextStyle(color: Colors.white),
                            iconEnabledColor: Colors.white,
                            items: hours.map((e) =>
                                DropdownMenuItem(
                                  value: e,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(isContinuousMode ? 'Hour $e' : 'Hour $e', style: const TextStyle(color: Colors.white),),
                                  ),
                                )).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (isContinuousMode) ...[
                      const SizedBox(width: 8),
                      const Text('to', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black54,),),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF222F3E),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedEndHour,
                              isExpanded: true,
                              dropdownColor: Color(0xFF222F3E),
                              hint: const Padding(padding: EdgeInsets.symmetric(horizontal: 8.0), child: Text('End Hour', style: TextStyle(color: Colors.white)),),
                              onChanged: (v) {
                                setState(() => selectedEndHour = v);
                                _onSelectionChanged();
                              },
                              style: const TextStyle(color: Colors.white),
                              iconEnabledColor: Colors.white,
                              items: getAvailableEndHours().map((e) =>
                                  DropdownMenuItem(
                                    value: e,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Text('Hour $e', style: const TextStyle(color: Colors.white),),
                                    ),
                                  )).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Table Headers
          Padding(
            padding: const EdgeInsets.only(top: 10, left: 4, right: 4),
            child: Container(
              decoration: BoxDecoration(
                color: kBackground,
                border: const Border(
                  bottom: BorderSide(color: kPrimary, width: 2),
                  top: BorderSide(color: kPrimary, width: 2),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text("STUDENT ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    const Expanded(
                      flex: 3,
                      child: Text("NAME", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            isContinuousMode && selectedEndHour != null
                                ? "HOURS $selectedHour-$selectedEndHour"
                                : "HOUR ${selectedHour ?? '-'}",
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18),
                            onSelected: (value) {
                              if (value == 'all_present') _markAll(true);
                              else if (value == 'all_absent') _markAll(false);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'all_present',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                                    SizedBox(width: 8),
                                    Text('Mark All Present'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'all_absent',
                                child: Row(
                                  children: [
                                    Icon(Icons.cancel, color: Colors.red, size: 18),
                                    SizedBox(width: 8),
                                    Text('Mark All Absent'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Student List with BLE indicators - IMPROVED VERSION
          Expanded(
            child: Stack(
              children: [
                filteredStudents.isEmpty
                    ? const Center(child: Text("No students found."))
                    : ListView.separated(
                  itemCount: filteredStudents.length,
                  separatorBuilder: (_, __) => Divider(color: kPrimary, height: 1, thickness: 0.7),
                  itemBuilder: (context, i) {
                    final s = filteredStudents[i];
                    final sid = s['id'];
                    final sname = s['name'];
                    final present = attendance[sid] ?? false;
                    final detectedViaBLE = detectedStudentIds.contains(sid);

                    return Container(
                      color: detectedViaBLE ? Colors.blue.shade50 : null, // Highlight BLE detected students
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        sid,
                                        style: TextStyle(
                                          fontWeight: detectedViaBLE ? FontWeight.bold : FontWeight.w500,
                                          color: detectedViaBLE ? Colors.blue.shade800 : Colors.black,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (detectedViaBLE) ...[
                                      SizedBox(width: 4),
                                      Icon(Icons.bluetooth_connected, color: Colors.blue, size: 12),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      sname,
                                      style: TextStyle(
                                        fontWeight: detectedViaBLE ? FontWeight.w600 : FontWeight.w400,
                                        fontSize: 15,
                                        color: detectedViaBLE ? Colors.blue.shade700 : Colors.black,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (detectedViaBLE) ...[
                                    SizedBox(width: 4),
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'AUTO',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 8,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Switch(
                                  key: ValueKey('${sid}_${present}_${detectedViaBLE}'), // Force rebuild with unique key
                                  value: present,
                                  activeColor: detectedViaBLE ? Colors.blue : Colors.green,
                                  inactiveThumbColor: Colors.red,
                                  onChanged: (v) => setState(() {
                                    attendance[sid] = v;
                                    if (!v) {
                                      // If manually marking as absent, remove from BLE detected set
                                      detectedStudentIds.remove(sid);
                                    }
                                  }),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                if (isLoadingAttendance)
                  Container(
                    color: Colors.white.withOpacity(0.8),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading attendance...'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}