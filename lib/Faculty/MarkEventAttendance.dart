import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'dart:math';
import 'package:ble_peripheral/ble_peripheral.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'dart:convert';

class MarkEventAttendance extends StatefulWidget {
  final String eventId;
  final String eventName;
  final List<String> students;
  final String durationType;
  final List<int> selectedPeriods;

  const MarkEventAttendance({
    Key? key,
    required this.eventId,
    required this.eventName,
    required this.students,
    required this.durationType,
    required this.selectedPeriods,
  }) : super(key: key);

  @override
  State<MarkEventAttendance> createState() => _MarkEventAttendanceState();
}

class _MarkEventAttendanceState extends State<MarkEventAttendance> {
  bool isLoading = true;
  List<Map<String, dynamic>> studentDetails = [];
  Map<String, String> attendanceStatus = {}; // studentId -> 'P' or 'A'
  int _currentPeriod = 1;
  String searchQuery = '';
  
  // BLE Broadcasting Variables
  bool _blePeripheralInitialized = false;
  bool isAdvertising = false;
  bool _isStartingBroadcast = false;
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<QuerySnapshot>? _responseSubscription;
  
  String? currentSessionId;
  String? currentProximityToken;
  Set<String> detectedStudentIds = {};
  List<Map<String, dynamic>> liveDetectedStudents = [];
  Timer? _liveUpdateTimer;
  
  int _determineCurrentPeriod() {
    final now = DateTime.now();
    final timeInMinutes = now.hour * 60 + now.minute;

    if (timeInMinutes < 9 * 60 + 50) return 1; // Before 9:50 -> P1
    if (timeInMinutes < 10 * 60 + 40) return 2; // 9:50 - 10:40 -> P2
    if (timeInMinutes < 11 * 60 + 45) return 3; // 10:40 - 11:45 -> P3
    if (timeInMinutes < 12 * 60 + 35) return 4; // 11:45 - 12:35 -> P4
    if (timeInMinutes < 14 * 60 + 15) return 5; // 12:35 - 14:15 -> P5
    if (timeInMinutes < 15 * 60 + 5) return 6; // 14:15 - 15:05 -> P6
    return 7; // 15:05 onwards -> P7
  }
  
  void _markAll(bool present) {
    setState(() {
      for (var s in studentDetails) {
        attendanceStatus[s['id']] = present ? 'P' : 'A';
      }
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.selectedPeriods.isNotEmpty) {
      int calculated = _determineCurrentPeriod();
      if (widget.selectedPeriods.contains(calculated)) {
        _currentPeriod = calculated;
      } else {
        _currentPeriod = widget.selectedPeriods.first;
      }
    }
    _initBlePeripheral();
    _fetchStudents();
  }

  @override
  void dispose() {
    _responseSubscription?.cancel();
    _liveUpdateTimer?.cancel();
    stopAdvertising();
    super.dispose();
  }

  Future<bool> _requestBlePermissions() async {
    try {
      await [
        Permission.bluetooth,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
        Permission.bluetoothScan,
      ].request();
      final adGranted = await Permission.bluetoothAdvertise.isGranted;
      final scanGranted = await Permission.bluetoothScan.isGranted;
      return adGranted && scanGranted;
    } catch (e) {
      debugPrint("Error requesting BLE permissions: $e");
      return false;
    }
  }

  Future<void> _initBlePeripheral() async {
    try {
      await _requestBlePermissions();
      await BlePeripheral.initialize();
      BlePeripheral.setAdvertisingStatusUpdateCallback(
          (bool advertising, String? error) {
        if (mounted) {
          setState(() => isAdvertising = advertising);
        }
      });
      _blePeripheralInitialized = true;
    } catch (e) {
      _blePeripheralInitialized = false;
    }
  }

  void _startScanningForStudents() async {
    try {
      _scanSubscription?.cancel();
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}

      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          String advName = result.advertisementData.advName;
          if (advName.isEmpty) advName = result.advertisementData.localName;
          if (advName.isEmpty) advName = result.device.platformName;
          if (advName.startsWith('STU_')) {
            final studentId = advName.substring(4);
            if (studentId.isNotEmpty) {
              _handleDirectBleAttendance(studentId);
            }
          }
        }
      });

      await FlutterBluePlus.startScan(
        continuousUpdates: true,
        androidUsesFineLocation: true,
      );
    } catch (e) {
      debugPrint("Error starting BLE scan: $e");
    }
  }

  Future<void> _handleDirectBleAttendance(String studentId) async {
    try {
      if (currentSessionId == null || !isAdvertising) return;
      if (detectedStudentIds.contains(studentId)) return;

      final student = studentDetails.firstWhere((s) => s['id'] == studentId, orElse: () => {});
      if (student.isEmpty) return;

      String resolvedName = student['name'];
      String studentSem = student['semester'];

      detectedStudentIds.add(studentId);
      if (mounted) {
        setState(() {
          attendanceStatus[studentId] = 'P';
          liveDetectedStudents.insert(0, {
            'id': studentId,
            'name': resolvedName,
            'timestamp': DateTime.now(),
            'isNew': true,
          });
        });
      }

      final String today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      final docRef = FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(studentId)
          .collection('attendance')
          .doc(studentSem);

      final docSnapshot = await docRef.get();
      Map<String, dynamic> data = docSnapshot.exists ? (docSnapshot.data() as Map<String, dynamic>) : {};
      Map<String, dynamic> todayData = data[today] != null ? Map<String, dynamic>.from(data[today] as Map) : {};
      
      todayData['${_currentPeriod}_checkpoint'] = 'P';
      
      // Instantly grant OD for this specific period
      todayData[(_currentPeriod - 1).toString()] = {widget.eventName: 'OD'};
      
      bool allMet = true;
      for (var p in widget.selectedPeriods) {
        if (p == _currentPeriod) continue;
        if (todayData['${p}_checkpoint'] != 'P') {
          allMet = false;
          break;
        }
      }
      
      if (allMet) {
        if (widget.durationType == 'full_day' || widget.durationType == 'multiple_days') {
          for (int i = 0; i < 7; i++) {
            todayData[i.toString()] = {widget.eventName: 'OD'};
          }
        } else if (widget.durationType == 'hours' && widget.selectedPeriods.length > 1) {
          int minP = widget.selectedPeriods.first;
          int maxP = widget.selectedPeriods.first;
          for (var p in widget.selectedPeriods) {
            if (p < minP) minP = p;
            if (p > maxP) maxP = p;
          }
          for (int i = minP - 1; i < maxP; i++) {
            todayData[i.toString()] = {widget.eventName: 'OD'};
          }
        }
      }
      
      await docRef.set({today: todayData}, SetOptions(merge: true));
      
      // Update overall stats for the portal
      await _updateStudentAttendancePercentage(studentId, studentSem);

    } catch (e) {
      debugPrint("Error processing BLE attendance write: $e");
    }
  }

  Future<void> startAdvertising() async {
    if (_isStartingBroadcast) return;
    setState(() => _isStartingBroadcast = true);

    final randomSuffix = List.generate(8, (index) => 'abcdefghijklmnopqrstuvwxyz0123456789'[Random().nextInt(36)]).join();
    final proximityToken = List.generate(4, (index) => 'abcdef0123456789'[Random().nextInt(16)]).join();
    final sessionId = "${widget.eventId}_$randomSuffix";

    try {
      await _requestBlePermissions();
      if (!_blePeripheralInitialized) {
        await _initBlePeripheral();
      }

      await BlePeripheral.startAdvertising(
        services: [],
        localName: "FAC_${randomSuffix}_$proximityToken",
      );

      setState(() {
        isAdvertising = true;
        _isStartingBroadcast = false;
        currentSessionId = sessionId;
        currentProximityToken = proximityToken;
        detectedStudentIds.clear();
        liveDetectedStudents.clear();
      });

      _startScanningForStudents();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Broadcasting started!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      setState(() => _isStartingBroadcast = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start broadcasting: $e')),
      );
    }
  }

  Future<void> stopAdvertising() async {
    if (!isAdvertising) return;
    try {
      await BlePeripheral.stopAdvertising();
      _scanSubscription?.cancel();
      await FlutterBluePlus.stopScan();
      _responseSubscription?.cancel();

      setState(() {
        isAdvertising = false;
        currentSessionId = null;
        liveDetectedStudents.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Broadcasting stopped"), backgroundColor: Colors.red),
      );
    } catch (e) {
      debugPrint("Error stopping BLE advertising: $e");
    }
  }

  Future<void> _fetchStudents() async {
    try {
      List<Map<String, dynamic>> details = [];
      for (String sId in widget.students) {
        final odQuery = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('od_requests')
            .collection('all_requests')
            .where('studentId', isEqualTo: sId)
            .where('eventId', isEqualTo: widget.eventId)
            .where('status', isEqualTo: 'approved')
            .get();

        if (odQuery.docs.isEmpty) continue;

        final doc = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('students')
            .collection('all_students')
            .doc(sId)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          details.add({
            'id': sId,
            'name': data['name'] ?? 'Unknown',
            'department': data['department'] ?? '',
            'semester': data['semester']?.toString() ?? (data['currentSemester'] is Map ? data['currentSemester']['semester'] : data['currentSemester'])?.toString() ?? 'V',
          });
          attendanceStatus[sId] = 'A'; // Default absent for events
        }
      }
      
      setState(() {
        studentDetails = details;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching event students: $e");
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitAttendance() async {
    setState(() => isLoading = true);
    try {
      final String today = DateFormat('dd-MM-yyyy').format(DateTime.now());
      
      for (var student in studentDetails) {
        final sId = student['id'];
        final sem = student['semester'];
        final status = attendanceStatus[sId];
        
        final docRef = FirebaseFirestore.instance
            .collection('colleges')
            .doc('students')
            .collection('all_students')
            .doc(sId)
            .collection('attendance')
            .doc(sem);

        if (status == 'P') {
          final docSnapshot = await docRef.get();
          Map<String, dynamic> data = docSnapshot.exists ? (docSnapshot.data() as Map<String, dynamic>) : {};
          Map<String, dynamic> todayData = data[today] != null ? Map<String, dynamic>.from(data[today] as Map) : {};

          todayData['${_currentPeriod}_checkpoint'] = 'P';
          
          // Instantly grant OD for this specific period
          todayData[(_currentPeriod - 1).toString()] = {widget.eventName: 'OD'};
          
          bool allMet = true;
          for (var p in widget.selectedPeriods) {
            if (p == _currentPeriod) continue;
            if (todayData['${p}_checkpoint'] != 'P') {
              allMet = false;
              break;
            }
          }

          if (allMet) {
            if (widget.durationType == 'full_day' || widget.durationType == 'multiple_days') {
              for (int i = 0; i < 7; i++) {
                todayData[i.toString()] = {widget.eventName: 'OD'};
              }
            } else if (widget.durationType == 'hours' && widget.selectedPeriods.length > 1) {
              int minP = widget.selectedPeriods.first;
              int maxP = widget.selectedPeriods.first;
              for (var p in widget.selectedPeriods) {
                if (p < minP) minP = p;
                if (p > maxP) maxP = p;
              }
              for (int i = minP - 1; i < maxP; i++) {
                todayData[i.toString()] = {widget.eventName: 'OD'};
              }
            }
          }

          await docRef.set({
            today: todayData,
          }, SetOptions(merge: true));
        }
        
        // Update overall stats for the portal
        await _updateStudentAttendancePercentage(sId, sem);
      }

      await stopAdvertising();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event attendance marked successfully!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error submitting event attendance: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
      setState(() => isLoading = false);
    }
  }

  void _showLiveDetectionDialog() {
    Timer? dialogTimer;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          dialogTimer?.cancel();
          dialogTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
            if (!isAdvertising || !mounted || !context.mounted) {
              timer.cancel();
              return;
            }
            try {
              setModalState(() {});
            } catch (e) {
              timer.cancel();
            }
          });
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade400, Colors.green.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.8, end: 1.2),
                        duration: const Duration(milliseconds: 1000),
                        builder: (context, double scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: const Icon(Icons.wifi_tethering, color: Colors.white, size: 28),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Broadcasting Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                            Text('Event: ${widget.eventName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                            Text('${detectedStudentIds.length} students detected', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.bluetooth, color: Colors.blue),
                            const SizedBox(width: 8),
                            Text('Live Student Signals (${liveDetectedStudents.length})', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: liveDetectedStudents.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.search, size: 64, color: Colors.grey),
                                    const SizedBox(height: 16),
                                    const Text('Waiting for student signals...', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                                    const SizedBox(height: 8),
                                    const Text('Students should open their app for auto-detection', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: liveDetectedStudents.length,
                                itemBuilder: (context, index) {
                                  final student = liveDetectedStudents[index];
                                  final isNew = student['isNew'] == true;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 500),
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isNew ? Colors.green.shade50 : Colors.blue.shade50,
                                      border: Border.all(color: isNew ? Colors.green : Colors.blue.shade200, width: isNew ? 2 : 1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: isNew ? Colors.green : Colors.blue,
                                        child: Text(student['name'].toString().isNotEmpty ? student['name'].toString().substring(0, 1).toUpperCase() : '?', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                                      ),
                                      title: Text(student['name'] ?? 'Unknown Student', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                                      subtitle: Text('ID: ${student['id']}'),
                                      trailing: isNew ? Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(12)), child: const Text('NEW', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white))) : const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        dialogTimer?.cancel();
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade300,
                        foregroundColor: Colors.black87,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close Preview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      dialogTimer?.cancel();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        title: Text(widget.eventName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!isLoading && !isAdvertising)
            _isStartingBroadcast
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.wifi_tethering, color: Colors.white, size: 28),
                    onPressed: startAdvertising,
                    tooltip: 'Start Broadcasting',
                  ),
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 24),
            tooltip: 'Scan QR Code',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(title: const Text('Scan Student QR', style: TextStyle(color: Colors.white)), backgroundColor: Colors.black),
                    body: MobileScanner(
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            try {
                              final data = jsonDecode(barcode.rawValue!);
                              final scannedEventId = data['eventId'];
                              final scannedStudentId = data['studentId'];

                              if (scannedEventId == widget.eventId) {
                                // Match found!
                                final student = studentDetails.firstWhere((s) => s['id'] == scannedStudentId, orElse: () => {});
                                if (student.isNotEmpty) {
                                  setState(() {
                                    attendanceStatus[scannedStudentId] = 'P';
                                  });
                                  Navigator.pop(context); // Close scanner
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('${student['name']} marked Present!'), backgroundColor: Colors.green),
                                  );
                                  return;
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Student not assigned to this event!'), backgroundColor: Colors.red),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Invalid QR for this event!'), backgroundColor: Colors.red),
                                );
                              }
                            } catch (e) {
                              // Not a valid JSON or our QR
                            }
                          }
                        }
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: studentDetails.isEmpty ? null : _submitAttendance,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F50)))
          : studentDetails.isEmpty
              ? const Center(child: Text("No students assigned."))
              : Column(
                  children: [
                    if (isAdvertising)
                      Container(
                        width: double.infinity,
                        color: Colors.green.shade100,
                        padding: const EdgeInsets.all(8),
                        child: GestureDetector(
                          onTap: _showLiveDetectionDialog,
                          child: Row(
                            children: [
                              const Icon(Icons.wifi_tethering, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Broadcasting ${widget.eventName} • ${detectedStudentIds.length} students detected • Tap to view live',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                ),
                              ),
                              TweenAnimationBuilder(
                                tween: Tween<double>(begin: 0.5, end: 1.0),
                                duration: const Duration(milliseconds: 1000),
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
                    if (widget.selectedPeriods.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        color: Colors.white,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Marking Attendance For:",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.orange.shade200),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _currentPeriod,
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.orange),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                                  items: widget.selectedPeriods.map((int p) {
                                    return DropdownMenuItem<int>(
                                      value: p,
                                      child: Text("Period $p"),
                                    );
                                  }).toList(),
                                  onChanged: (int? newValue) {
                                    if (newValue != null) {
                                      setState(() {
                                        _currentPeriod = newValue;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Search Students
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 3, offset: Offset(1, 2)),
                          ],
                        ),
                        child: TextField(
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: "Search students",
                            hintStyle: TextStyle(fontSize: 13),
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search),
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          ),
                          onChanged: (val) => setState(() => searchQuery = val),
                        ),
                      ),
                    ),

                    // Table Headers
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFFF9F9F9),
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFFF7F50), width: 2),
                            top: BorderSide(color: Color(0xFFFF7F50), width: 2),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
                          child: Row(
                            children: [
                              const Expanded(
                                flex: 2,
                                child: Text("STUDENT ID", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                              const Expanded(
                                flex: 3,
                                child: Text("STUDENT NAME", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                              Expanded(
                                flex: 2,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 18),
                                      onSelected: (value) {
                                        if (value == 'all_present')
                                          _markAll(true);
                                        else if (value == 'all_absent')
                                          _markAll(false);
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

                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final filteredStudents = studentDetails
                              .where((s) =>
                                  s['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
                                  s['id'].toString().toLowerCase().contains(searchQuery.toLowerCase()))
                              .toList();

                          if (filteredStudents.isEmpty) {
                            return const Center(child: Text("No students found."));
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.all(0),
                            itemCount: filteredStudents.length,
                            separatorBuilder: (_, __) => const Divider(color: Color(0xFFFF7F50), height: 1, thickness: 0.7),
                            itemBuilder: (context, index) {
                              final s = filteredStudents[index];
                              final sid = s['id'];
                              final sname = s['name'];
                              final status = attendanceStatus[sid] ?? 'A';
                              final present = status == 'P';
                              final detectedViaBLE = detectedStudentIds.contains(sid);

                              return Container(
                                color: detectedViaBLE ? Colors.blue.shade50 : null,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (detectedViaBLE) ...[
                                                const SizedBox(width: 4),
                                                const Icon(Icons.bluetooth_connected, color: Colors.blue, size: 12),
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
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (detectedViaBLE) ...[
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue,
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('AUTO', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
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
                                            key: ValueKey('${sid}_${present}_$detectedViaBLE'),
                                            value: present,
                                            activeColor: detectedViaBLE ? Colors.blue : Colors.green,
                                            inactiveThumbColor: Colors.red,
                                            onChanged: (v) => setState(() {
                                              attendanceStatus[sid] = v ? 'P' : 'A';
                                              if (!v) {
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
                          );
                        }
                      ),
                    ),
                  ],
                ),
    );
  }
  Future<void> _updateStudentAttendancePercentage(String sId, String sem) async {
    final attendanceRef = FirebaseFirestore.instance
        .collection('colleges')
        .doc('students')
        .collection('all_students')
        .doc(sId)
        .collection('attendance')
        .doc(sem);

    final docSnap = await attendanceRef.get();
    final data = docSnap.data() ?? {};

    int presentCount = 0;
    int absentCount = 0;
    int onDutyCount = 0;
    int totalMarks = 0;

    data.forEach((key, value) {
      if (key == 'P' || key == 'A' || key == 'OD') return;
      if (value is Map<String, dynamic>) {
        value.forEach((hour, hourEntry) {
          if (hourEntry is Map<String, dynamic>) {
            hourEntry.forEach((subject, status) {
              totalMarks++;
              if (status == 'P')
                presentCount++;
              else if (status == 'A')
                absentCount++;
              else if (status == 'OD') onDutyCount++;
            });
          }
        });
      }
    });

    double presentPercentage = totalMarks > 0 ? (presentCount / totalMarks) * 100 : 0;
    double absentPercentage = totalMarks > 0 ? (absentCount / totalMarks) * 100 : 0;
    double onDutyPercentage = totalMarks > 0 ? (onDutyCount / totalMarks) * 100 : 0;

    await attendanceRef.set({
      'P': presentPercentage,
      'A': absentPercentage,
      'OD': onDutyPercentage,
    }, SetOptions(merge: true));
  }
}
