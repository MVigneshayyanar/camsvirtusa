import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'dart:ui';
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
  List<String> assignedClasses = [];
  List<String> todayClasses = [];
  List<String> allClasses = [];
  bool isLoading = true;
  String error = '';
  String facultyName = '';
  String departmentId = '';
  String currentClass = '';
  String abbreviation = '';
  String searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> todaySwaps = [];
  List<Map<String, dynamic>> deptFaculties = [];

  final periodStartTimes = [
    {'hour': 9, 'minute': 0},
    {'hour': 9, 'minute': 50},
    {'hour': 10, 'minute': 55},
    {'hour': 11, 'minute': 45},
    {'hour': 13, 'minute': 25},
    {'hour': 14, 'minute': 15},
    {'hour': 15, 'minute': 20},
  ];
  final periodEndTimes = [
    {'hour': 9, 'minute': 50},
    {'hour': 10, 'minute': 40},
    {'hour': 11, 'minute': 45},
    {'hour': 12, 'minute': 35},
    {'hour': 14, 'minute': 15},
    {'hour': 15, 'minute': 5},
    {'hour': 16, 'minute': 10},
  ];

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
        abbreviation = data['abbreviation'] ?? '';
        assignedClasses = List<String>.from(data['classes'] ?? []);
        error = '';
      });

      if (departmentId.isNotEmpty) {
        final classesSnapshot = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('departments')
            .collection('all_departments')
            .doc(departmentId)
            .collection('clasees')
            .get();

        final facultiesSnapshot = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('faculties')
            .collection('all_faculties')
            .where('department', isEqualTo: departmentId)
            .get();

        setState(() {
          allClasses = classesSnapshot.docs.map((doc) => doc.id).toList();
          deptFaculties = facultiesSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'name': doc.data()['name'] ?? 'Unknown',
                    'abbreviation': doc.data()['abbreviation'] ?? '',
                    'classes': List<String>.from(doc.data()['classes'] ?? []),
                  })
              .where((f) => f['id'] != widget.facultyId)
              .toList();
        });
      }

      await _calculateCurrentClass();
    } catch (e) {
      setState(() {
        error = 'Error loading faculty details: $e';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _calculateCurrentClass() async {
    try {
      final now = DateTime.now();
      int currentIdx = -1;
      for (int i = 0; i < 7; i++) {
        final start = DateTime(now.year, now.month, now.day,
            periodStartTimes[i]['hour']!, periodStartTimes[i]['minute']!);
        final end = DateTime(now.year, now.month, now.day,
            periodEndTimes[i]['hour']!, periodEndTimes[i]['minute']!);
        if ((now.isAfter(start) || now.isAtSameMomentAs(start)) &&
            (now.isBefore(end) || now.isAtSameMomentAs(end))) {
          currentIdx = i;
          break;
        }
      }

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

      // Fetch swaps
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final swapsSnapshot = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(departmentId)
          .collection('swaps')
          .where('date', isEqualTo: dateStr)
          .get();

      final List<Map<String, dynamic>> activeSwaps = [];
      for (var d in swapsSnapshot.docs) {
        activeSwaps.add(d.data());
      }

      if (today == "Saturday" || today == "Sunday") {
        if (mounted) {
          setState(() {
            todaySwaps = activeSwaps;
            todayClasses = assignedClasses;
          });
        }
        return;
      }

      List<String> tempTodayClasses = [];
      String? tempCurrentClass;

      for (var cName in assignedClasses) {
        final classDoc = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('departments')
            .collection('all_departments')
            .doc(departmentId)
            .collection('clasees')
            .doc(cName)
            .get();
        if (classDoc.exists) {
          final classData = classDoc.data()!;
          final currentSemesterField = classData['currentSemester'];
          String currentSem = 'V';
          if (currentSemesterField is Map) {
            currentSem = currentSemesterField['semester']?.toString() ?? 'V';
          } else {
            currentSem = currentSemesterField?.toString() ?? 'V';
          }
          final timetables = classData['timetables'] as Map?;
          if (timetables != null) {
            final semTimetable = timetables[currentSem];
            if (semTimetable != null && semTimetable[today] != null) {
              final todayPeriods = semTimetable[today] as List;
              bool hasClassToday = false;
              for (int j = 0; j < todayPeriods.length; j++) {
                var subjectStr = todayPeriods[j]?.toString() ?? "";
                if (subjectStr.contains(widget.facultyId) ||
                    subjectStr.contains(abbreviation)) {
                  hasClassToday = true;
                  if (currentIdx == j) {
                    tempCurrentClass = cName;
                  }
                }
              }
              if (hasClassToday) {
                tempTodayClasses.add(cName);
              }
            }
          }
        }
      }

      // Adjust based on active swaps
      for (var swap in activeSwaps) {
        final f1 = swap['faculty1Id']?.toString() ?? "";
        final f2 = swap['faculty2Id']?.toString() ?? "";
        final c1 = swap['faculty1Class']?.toString() ?? "";
        final c2 = swap['faculty2Class']?.toString() ?? "";
        final p1 = swap['faculty1Period'] as int? ?? -1;
        final p2 = swap['faculty2Period'] as int? ?? -1;

        if (f1 == widget.facultyId) {
          if (c2.isNotEmpty && !tempTodayClasses.contains(c2)) {
            tempTodayClasses.add(c2);
          }
          if (currentIdx == p2) {
            tempCurrentClass = c2;
          }
          if (currentIdx == p1 && tempCurrentClass == c1) {
            tempCurrentClass = null;
          }
        } else if (f2 == widget.facultyId) {
          if (c1.isNotEmpty && !tempTodayClasses.contains(c1)) {
            tempTodayClasses.add(c1);
          }
          if (currentIdx == p1) {
            tempCurrentClass = c1;
          }
          if (currentIdx == p2 && tempCurrentClass == c2) {
            tempCurrentClass = null;
          }
        }
      }

      if (mounted) {
        setState(() {
          todaySwaps = activeSwaps;
          todayClasses =
              tempTodayClasses.isEmpty ? assignedClasses : tempTodayClasses;
          if (tempCurrentClass != null) {
            currentClass = tempCurrentClass;
          } else {
            currentClass = '';
          }
        });
      }
    } catch (e) {
      print("Error calculating current class: $e");
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

  void _showSwapDialog() {
    String? mySelectedClass =
        assignedClasses.isNotEmpty ? assignedClasses.first : null;
    int mySelectedPeriod = 0;
    Map<String, dynamic>? selectedFaculty =
        deptFaculties.isNotEmpty ? deptFaculties.first : null;
    String? targetSelectedClass;
    int targetSelectedPeriod = 6;

    if (selectedFaculty != null &&
        (selectedFaculty['classes'] as List).isNotEmpty) {
      targetSelectedClass =
          (selectedFaculty['classes'] as List).first.toString();
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final targetClasses = selectedFaculty != null
                ? List<String>.from(selectedFaculty!['classes'] ?? [])
                : <String>[];

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Row(
                children: [
                  Icon(Icons.swap_horiz, color: Color(0xFFFF7F50)),
                  SizedBox(width: 8),
                  Text(
                    'Swap Hours',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Hour details:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: mySelectedClass,
                      decoration: const InputDecoration(
                        labelText: 'Select Your Class',
                        border: OutlineInputBorder(),
                      ),
                      items: assignedClasses.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setDialogState(() {
                          mySelectedClass = newValue;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: mySelectedPeriod,
                      decoration: const InputDecoration(
                        labelText: 'Select Your Period',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(7, (index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text(
                              'Period ${index + 1} (${_getPeriodTimeLabel(index)})'),
                        );
                      }),
                      onChanged: (newValue) {
                        setDialogState(() {
                          mySelectedPeriod = newValue ?? 0;
                        });
                      },
                    ),
                    const Divider(height: 24, thickness: 1),
                    const Text(
                      'Swap With (Target Faculty):',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedFaculty,
                      decoration: const InputDecoration(
                        labelText: 'Select Faculty',
                        border: OutlineInputBorder(),
                      ),
                      items: deptFaculties.map((Map<String, dynamic> val) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: val,
                          child: Text(val['name']),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setDialogState(() {
                          selectedFaculty = newValue;
                          final newTargetClasses = selectedFaculty != null
                              ? List<String>.from(
                                  selectedFaculty!['classes'] ?? [])
                              : <String>[];
                          targetSelectedClass = newTargetClasses.isNotEmpty
                              ? newTargetClasses.first
                              : null;
                        });
                      },
                    ),
                    if (targetClasses.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: targetSelectedClass,
                        decoration: const InputDecoration(
                          labelText: 'Select Their Class',
                          border: OutlineInputBorder(),
                        ),
                        items: targetClasses.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                        onChanged: (newValue) {
                          setDialogState(() {
                            targetSelectedClass = newValue;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      value: targetSelectedPeriod,
                      decoration: const InputDecoration(
                        labelText: 'Select Their Period',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(7, (index) {
                        return DropdownMenuItem<int>(
                          value: index,
                          child: Text(
                              'Period ${index + 1} (${_getPeriodTimeLabel(index)})'),
                        );
                      }),
                      onChanged: (newValue) {
                        setDialogState(() {
                          targetSelectedPeriod = newValue ?? 0;
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7F50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    if (mySelectedClass == null ||
                        selectedFaculty == null ||
                        targetSelectedClass == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Please select all fields')),
                      );
                      return;
                    }
                    Navigator.of(context).pop();
                    await _createSwap(
                      myClass: mySelectedClass!,
                      myPeriod: mySelectedPeriod,
                      targetFacultyId: selectedFaculty!['id'],
                      targetFacultyName: selectedFaculty!['name'],
                      targetClass: targetSelectedClass!,
                      targetPeriod: targetSelectedPeriod,
                    );
                  },
                  child: const Text('Request Swap',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getPeriodTimeLabel(int index) {
    final startLabels = [
      "9:00 AM",
      "9:50 AM",
      "10:55 AM",
      "11:45 AM",
      "1:25 PM",
      "2:15 PM",
      "3:20 PM"
    ];
    if (index >= 0 && index < startLabels.length) {
      return startLabels[index];
    }
    return "";
  }

  Future<void> _createSwap({
    required String myClass,
    required int myPeriod,
    required String targetFacultyId,
    required String targetFacultyName,
    required String targetClass,
    required int targetPeriod,
  }) async {
    setState(() => isLoading = true);
    try {
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);

      await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(departmentId)
          .collection('swaps')
          .add({
        'date': dateStr,
        'faculty1Id': widget.facultyId,
        'faculty1Name': facultyName,
        'faculty1Class': myClass,
        'faculty1Period': myPeriod,
        'faculty2Id': targetFacultyId,
        'faculty2Name': targetFacultyName,
        'faculty2Class': targetClass,
        'faculty2Period': targetPeriod,
        'timestamp': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully swapped hour with $targetFacultyName!'),
          backgroundColor: Colors.green,
        ),
      );

      await _calculateCurrentClass();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to swap hours: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        titleSpacing: 0,
        title: const Text(
          'ATTENDANCE REGISTER',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
              ? Center(child: Text(error))
              : Column(
                  children: [
                    if (todaySwaps.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0), // Light orange
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFFB74D)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.swap_horiz,
                                    color: Color(0xFFE65100), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  "Today's Active Swaps",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE65100),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...todaySwaps.map((swap) {
                              final f1Name = swap['faculty1Name'] ?? 'Unknown';
                              final f2Name = swap['faculty2Name'] ?? 'Unknown';
                              final c1 = swap['faculty1Class'] ?? '';
                              final c2 = swap['faculty2Class'] ?? '';
                              final p1 =
                                  (swap['faculty1Period'] as int? ?? 0) + 1;
                              final p2 =
                                  (swap['faculty2Period'] as int? ?? 0) + 1;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Text(
                                  "• $f1Name ($c1, P$p1) ⇆ $f2Name ($c2, P$p2)",
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF5D4037)),
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            searchQuery = val.toLowerCase();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search any class by ID to swap...',
                          hintStyle: const TextStyle(fontSize: 14),
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final displayClasses = searchQuery.isEmpty
                              ? todayClasses
                              : allClasses
                                  .where((c) =>
                                      c.toLowerCase().contains(searchQuery))
                                  .toList();

                          if (displayClasses.isEmpty) {
                            return const Center(
                                child: Text('No classes found'));
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            itemCount: displayClasses.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, idx) {
                              final className = displayClasses[idx];
                              final isCurrent = className == currentClass;
                              final isAssigned =
                                  todayClasses.contains(className);

                              return Card(
                                color: isCurrent
                                    ? Colors.green.shade50
                                    : Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: isCurrent
                                      ? BorderSide(
                                          color: Colors.green, width: 2)
                                      : BorderSide.none,
                                ),
                                elevation: isCurrent ? 4 : 2,
                                child: ListTile(
                                  leading: Icon(Icons.class_,
                                      color: isCurrent
                                          ? Colors.green
                                          : const Color(0xFF36454F)),
                                  title: Text(
                                    className +
                                        (isCurrent
                                            ? " (Ongoing)"
                                            : (!isAssigned
                                                ? " (Other Class)"
                                                : "")),
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500),
                                  ),
                                  trailing: Icon(Icons.arrow_forward_ios,
                                      color: isCurrent
                                          ? Colors.green
                                          : const Color(0xFF36454F)),
                                  onTap: () => _openClassAttendance(className),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
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
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII'
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
    final now = DateTime.now();
    final day = now.weekday; // 1 = Monday, 7 = Sunday
    final minutesSinceMidnight = now.hour * 60 + now.minute;
    final startMinutes = 9 * 60; // 9:00 AM
    final endMinutes = 16 * 60 + 10; // 4:10 PM

    if (day == DateTime.saturday ||
        day == DateTime.sunday ||
        minutesSinceMidnight < startMinutes ||
        minutesSinceMidnight > endMinutes) {
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
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFF7F50).withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.wifi_tethering_off_rounded,
                      color: Color(0xFFFF7F50),
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    "Broadcasting Unavailable",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Broadcasting is active only from Monday to Friday (9:00 AM to 4:10 PM). Saturday and Sunday are not available.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
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
                        "OK",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

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

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy
                .medium, // Medium accuracy is faster and sufficient for classroom proximity
          ).timeout(const Duration(seconds: 4));
          facLat = pos.latitude;
          facLng = pos.longitude;
        } catch (e) {
          print(
              "⚠️ getCurrentPosition failed or timed out: $e. Trying last known position...");
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

    print(
        "🔄 Processing ${snapshot.docs.length} responses for session: $currentSessionId");

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
              displayName = studentData['name'] ??
                  studentData['student_name'] ??
                  studentId;
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
          bool exists =
              liveDetectedStudents.any((s) => s['id'] == student['id']);
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

      print(
          "✅ State updated: ${detectedStudentIds.length} total detected, ${newDetectedStudents.length} new");
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
        .snapshots() // Remove orderBy to avoid index issues
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

          if (displayName.isEmpty ||
              displayName == 'Unknown' ||
              displayName == 'Unknown Student') {
            // Try to find student in the main students list
            final studentData = students.firstWhere(
              (s) => s['id'] == studentId,
              orElse: () => <String, dynamic>{},
            );

            if (studentData.isNotEmpty) {
              displayName = studentData['name'] ??
                  studentData['student_name'] ??
                  studentId;
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
            bool exists =
                liveDetectedStudents.any((s) => s['id'] == student['id']);
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

        print(
            "🔄 State updated: ${detectedStudentIds.length} total detected, ${newDetectedStudents.length} new");
      }
    } catch (e) {
      print('❌ Error fetching live student responses: $e');
    }
  }

  String _getStudentName(String studentId) {
    final student = students.firstWhere((s) => s['id'] == studentId,
        orElse: () => {'name': 'Unknown Student'});
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
            orElse: () =>
                {'class': widget.className}, // Use widget.className as fallback
          )['class'] ??
          widget.className;

      print("📊 Updating Firestore for student $studentId in class $classId");
    } catch (e) {
      print("❌ Error marking student present: $e");
    }
  }

  // IMPROVED METHOD: Merge BLE detected students with attendance UI
  Future<void> _mergeBLEDetectedStudents() async {
    if (currentSessionId == null) return;

    try {
      print(
          "🔍 Checking for BLE detected students for session: $currentSessionId");

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
          attendance = Map.from(
              attendance); // Create new map reference to trigger rebuild
        });

        print("🎯 Total BLE detected students: $detectedCount");
        print("👥 Detected students: ${detectedStudentNames.join(', ')}");

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('✅ $detectedCount students marked via BLE detection'),
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

          dialogTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
            if (!isAdvertising || !mounted || !context.mounted) {
              timer.cancel();
              return;
            }
            try {
              setModalState(() {
                // Force refresh of modal content
              });
            } catch (e) {
              timer.cancel();
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
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      TweenAnimationBuilder(
                        tween: Tween<double>(begin: 0.8, end: 1.2),
                        duration: Duration(milliseconds: 1000),
                        builder: (context, double scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: Icon(Icons.wifi_tethering,
                                color: Colors.white, size: 28),
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
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              'Subject: ${advertisingSubject ?? 'Unknown'}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              '${students.where((s) => attendance[s['id']] == true).length} students detected',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          dialogTimer?.cancel();
                          stopAdvertising();
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.stop, size: 14),
                        label: const Text('Stop Broadcasting',
                            style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats section
                Builder(builder: (context) {
                  final presentStudents = students.where((s) => attendance[s['id']] == true).toList();
                  final absentStudents = students.where((s) => attendance[s['id']] != true).toList();
                  final presentCount = presentStudents.length;
                  final absentCount = absentStudents.length;
                  return Container(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        _buildStatCard('Total', students.length.toString(),
                            Icons.people, Colors.blue),
                        SizedBox(width: 10),
                        _buildStatCard('Present', presentCount.toString(),
                            Icons.check_circle, Colors.green, onTap: () => _showStudentsDialog("Present Students", presentStudents)),
                        SizedBox(width: 10),
                        _buildStatCard('Absent', absentCount.toString(),
                            Icons.cancel, Colors.red, onTap: () => _showStudentsDialog("Absent Students", absentStudents)),
                      ],
                    ),
                  );
                }),

                // Live students list
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            Icon(Icons.bluetooth, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Live Student Signals (${liveDetectedStudents.length})',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500),
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
                                    Icon(Icons.search,
                                        size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'Waiting for student signals...',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Students should open their app for auto-detection',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey,
                                          fontWeight: FontWeight.normal),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: liveDetectedStudents.length,
                                itemBuilder: (context, index) {
                                  final student = liveDetectedStudents[index];
                                  final isNew = student['isNew'] == true;
                                  final timestamp =
                                      student['timestamp'] as DateTime;

                                  return AnimatedContainer(
                                    duration: Duration(milliseconds: 500),
                                    margin: EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: isNew
                                          ? Colors.green.shade50
                                          : Colors.blue.shade50,
                                      border: Border.all(
                                        color: isNew
                                            ? Colors.green
                                            : Colors.blue.shade200,
                                        width: isNew ? 2 : 1,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor:
                                            isNew ? Colors.green : Colors.blue,
                                        child: Text(
                                          student['name'].toString().isNotEmpty
                                              ? student['name']
                                                  .toString()
                                                  .substring(0, 1)
                                                  .toUpperCase()
                                              : '?',
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      title: Text(
                                        student['name'] ?? 'Unknown Student',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('ID: ${student['id']}'),
                                          Text(
                                            'Detected: ${DateFormat('HH:mm:ss').format(timestamp)}',
                                            style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          if (isNew) ...[
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Colors.green,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'NEW',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight:
                                                        FontWeight.w500),
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
                    borderRadius:
                        BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Session ID:',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                          Text(
                              currentSessionId?.substring(
                                      currentSessionId!.length - 8) ??
                                  'Unknown',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: isSaving
                            ? null
                            : () async {
                                dialogTimer?.cancel();
                                Navigator.pop(context);
                                await _saveAttendance();
                              },
                        icon: const Icon(Icons.save),
                        label: const Text('Save Attendance'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7F50),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Text(
                label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStudentsDialog(String title, List<Map<String, dynamic>> list) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Container(
            width: double.maxFinite,
            height: 300,
            child: list.isEmpty
                ? const Center(child: Text("No students found."))
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final student = list[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text((student['name'] ?? 'U')[0]),
                        ),
                        title: Text(student['name'] ?? 'Unknown'),
                        subtitle: Text(student['id'] ?? 'Unknown ID'),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  // All your existing methods remain the same...
  Future<void> _initData() async {
    try {
      selectedSemester = semesters.first;
      selectedHour = null;

      try {
        final classDoc = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('departments')
            .collection('all_departments')
            .doc(widget.departmentId)
            .collection('clasees')
            .doc(widget.className)
            .get();
        if (classDoc.exists) {
          final classData = classDoc.data()!;
          final semesterField = classData['currentSemester'];
          if (semesterField is Map) {
            selectedSemester =
                semesterField['semester']?.toString() ?? semesters.first;
          } else if (semesterField != null) {
            selectedSemester = semesterField.toString();
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
          final today = daysOfWeek[now.weekday - 1];

          final periodStartTimes = [
            {'hour': 9, 'minute': 0},
            {'hour': 9, 'minute': 50},
            {'hour': 10, 'minute': 55},
            {'hour': 11, 'minute': 45},
            {'hour': 13, 'minute': 25},
            {'hour': 14, 'minute': 15},
            {'hour': 15, 'minute': 20}
          ];
          final periodEndTimes = [
            {'hour': 9, 'minute': 50},
            {'hour': 10, 'minute': 40},
            {'hour': 11, 'minute': 45},
            {'hour': 12, 'minute': 35},
            {'hour': 14, 'minute': 15},
            {'hour': 15, 'minute': 5},
            {'hour': 16, 'minute': 10}
          ];

          int currentIdx = -1;
          for (int i = 0; i < 7; i++) {
            final start = DateTime(now.year, now.month, now.day,
                periodStartTimes[i]['hour']!, periodStartTimes[i]['minute']!);
            final end = DateTime(now.year, now.month, now.day,
                periodEndTimes[i]['hour']!, periodEndTimes[i]['minute']!);
            if ((now.isAfter(start) || now.isAtSameMomentAs(start)) &&
                (now.isBefore(end) || now.isAtSameMomentAs(end))) {
              currentIdx = i;
              break;
            }
          }

          if (currentIdx != -1 && today != "Saturday" && today != "Sunday") {
            final timetables = classData['timetables'] as Map?;
            if (timetables != null) {
              final semTimetable = timetables[selectedSemester];
              if (semTimetable != null && semTimetable[today] != null) {
                final todayPeriods = semTimetable[today] as List;
                if (currentIdx < todayPeriods.length) {
                  String subStr = todayPeriods[currentIdx]?.toString() ?? "";
                  if (subStr.isNotEmpty) {
                    final parts = subStr.split('/');
                    if (parts.isNotEmpty) {
                      selectedSubject = parts[0].trim();
                    }
                    selectedHour = (currentIdx + 1).toString();
                  }
                }
              }
            }
          } else {
            selectedHour = null;
          }
        }
      } catch (e) {
        print('Error fetching auto-select data: $e');
      }
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
      final availableSubjects = getSubjectsForThisFaculty().isNotEmpty
          ? getSubjectsForThisFaculty()
          : subjects;
      if (selectedSubject == null ||
          !availableSubjects.contains(selectedSubject)) {
        selectedSubject =
            availableSubjects.isNotEmpty ? availableSubjects.first : null;
      }
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

        if (data.containsKey('courseMapping') &&
            data['courseMapping'] != null) {
          final mappingData = data['courseMapping'] as Map<String, dynamic>;
          if (mappingData.containsKey(semester)) {
            final mappings =
                List<Map<String, dynamic>>.from(mappingData[semester] ?? []);
            subjects =
                mappings.map((m) => m['abbreviation'] as String).toList();
            print(
                '✅ Fetched ${subjects.length} subjects from courseMapping for semester $semester');
          }
        }

        // Fallback for older data format
        if (subjects.isEmpty && data.containsKey(semester)) {
          subjects = List<String>.from(data[semester] ?? []);
          print(
              '✅ Fetched ${subjects.length} subjects from legacy array for semester $semester');
        }
      } else {
        subjects = [];
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

        if (data.containsKey('courseMapping') &&
            data['courseMapping'] != null) {
          final mappingData = data['courseMapping'] as Map<String, dynamic>;

          if (mappingData.containsKey(semester)) {
            facultySubjectMappings = List<Map<String, dynamic>>.from(
              mappingData[semester] ?? [],
            );
            print(
                '✅ Fetched ${facultySubjectMappings.length} faculty mappings from courseMapping');
          } else {
            facultySubjectMappings = [];
          }
        } else if (data.containsKey('faculty') && data['faculty'] != null) {
          // Legacy support
          final facultyData = data['faculty'] as Map<String, dynamic>;
          if (facultyData.containsKey(semester)) {
            facultySubjectMappings = List<Map<String, dynamic>>.from(
              facultyData[semester] ?? [],
            );
          } else {
            facultySubjectMappings = [];
          }
        } else {
          facultySubjectMappings = [];
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
    if (selectedSubject == null || students.isEmpty || selectedSemester == null)
      return;

    if (selectedHour == null) {
      setState(() {
        attendance = {for (var s in students) s['id']: false};
      });
      return;
    }
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
        final end =
            (i + batchSize < students.length) ? i + batchSize : students.length;
        batches.add(students.sublist(i, end));
      }

      final futures = batches
          .map((batch) => _loadAttendanceForBatch(batch, dateKey, hourIndices));
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
          if (hourEntry != null &&
              hourEntry is Map &&
              hourEntry.containsKey(selectedSubject!)) {
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

  bool _isAfterFourTen() {
    final now = DateTime.now();
    return now.hour > 16 || (now.hour == 16 && now.minute > 10);
  }

  void _onSelectionChanged() {
    if (selectedSubject != null &&
        selectedHour != null &&
        students.isNotEmpty &&
        selectedSemester != null) {
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
    return hours
        .where((h) => (int.tryParse(h) ?? 1) >= startHourIndex)
        .toList();
  }

  List<String> getSubjectsForThisFaculty() {
    return facultySubjectMappings
        .where((m) =>
            m['facultyId'] == widget.facultyId ||
            m['facultyId2'] == widget.facultyId)
        .map((m) => (m['abbreviation'] ?? m['subject'] ?? '') as String)
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _updateAttendancePercentagesFromHistory() async {
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

      double presentPercentage =
          totalMarks > 0 ? (presentCount / totalMarks) * 100 : 0;
      double absentPercentage =
          totalMarks > 0 ? (absentCount / totalMarks) * 100 : 0;
      double onDutyPercentage =
          totalMarks > 0 ? (onDutyCount / totalMarks) * 100 : 0;

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
        const SnackBar(
            content: Text(
                'Please select semester, subject, hour and have students')),
      );
      return;
    }
    setState(() => isSaving = true);

    final ValueNotifier<int> progressNotifier = ValueNotifier<int>(0);
    int totalStudents = students.length;
    int completedStudents = 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: kPrimary),
              const SizedBox(height: 20),
              const Text("Saving Attendance",
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              ValueListenableBuilder<int>(
                valueListenable: progressNotifier,
                builder: (context, value, child) {
                  return Text(
                    "$value%",
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                  );
                },
              ),
            ],
          ),
        );
      },
    );

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
        final end =
            (i + batchSize < students.length) ? i + batchSize : students.length;
        batches.add(students.sublist(i, end));
      }
      final futures = batches.map((batch) =>
          _saveAttendanceForBatch(batch, dateKey, hourIndices, subject, () {
            completedStudents++;
            progressNotifier.value =
                ((completedStudents / totalStudents) * 100).toInt();
          }));
      await Future.wait(futures);

      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss loading dialog

      final hourText = isContinuousMode && selectedEndHour != null
          ? 'Hours $selectedHour-$selectedEndHour'
          : 'Hour $selectedHour';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance saved successfully for $hourText')),
      );

      // Fire and forget updating percentages so it doesn't block UI
      _updateAttendancePercentagesFromHistory();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  Future<void> _saveAttendanceForBatch(
    List<Map<String, dynamic>> batch,
    String dateKey,
    List<int> hourIndices,
    String subject,
    VoidCallback onStudentSaved,
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
        await attendanceRef
            .set({dateKey: attendanceDay}, SetOptions(merge: true));
        onStudentSaved();
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
    final filteredStudents = students
        .where((s) =>
            s['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
            s['id'].toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        titleSpacing: 0,
        title: const Text(
          'MARK ATTENDANCE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        actions: [
          // BLE Broadcasting Button (Start Only)
          if (!isLoading && error.isEmpty && !isAdvertising)
            IconButton(
              icon: const Icon(
                Icons.wifi_tethering,
                color: Colors.white,
                size: 28,
              ),
              onPressed: startAdvertising,
              tooltip: 'Start Broadcasting',
            ),
        ],
        leading: const BackButton(color: Colors.white),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Loading class data...',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Please wait',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            )
          : error.isNotEmpty
              ? Center(child: Text(error, style: const TextStyle(fontSize: 13)))
              : Column(
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
                        'Broadcasting ${advertisingSubject ?? 'Unknown'} • ${students.where((s) => attendance[s['id']] == true).length} students detected • Tap to view live',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500),
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

          // Top Dropdowns: Semester, Subject and Hour
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSemester,
                        isExpanded: true,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('Select Sem',
                              style: TextStyle(fontSize: 13)),
                        ),
                        onChanged: (v) async {
                          if (v != null) {
                            setState(() => selectedSemester = v);
                            await _loadSemesterData(v);
                            _onSelectionChanged();
                          }
                        },
                        items: semesters
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(e,
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Builder(builder: (context) {
                      final availableSubjects =
                          getSubjectsForThisFaculty().isNotEmpty
                              ? getSubjectsForThisFaculty()
                              : subjects;
                      return DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: availableSubjects.contains(selectedSubject)
                              ? selectedSubject
                              : null,
                          isExpanded: true,
                          hint: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text('Select Subject',
                                style: TextStyle(fontSize: 13)),
                          ),
                          onChanged: (v) {
                            setState(() => selectedSubject = v);
                            _onSelectionChanged();
                          },
                          items: availableSubjects
                              .map((e) => DropdownMenuItem(
                                    value: e,
                                    child: Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(e,
                                          style: const TextStyle(fontSize: 13)),
                                    ),
                                  ))
                              .toList(),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF222F3E),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        selectedHour != null && !_isAfterFourTen()
                            ? 'Hour $selectedHour'
                            : 'No Hours',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Present and Absent Count Row (instead of Date Picker)
          Builder(builder: (context) {
            final presentStudents = students.where((s) => attendance[s['id']] == true).toList();
            final absentStudents = students.where((s) => attendance[s['id']] != true).toList();
            final presentCount = presentStudents.length;
            final absentCount = absentStudents.length;
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showStudentsDialog("Present Students", presentStudents),
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
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'PRESENT',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showStudentsDialog("Absent Students", absentStudents),
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
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'ABSENT',
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Search Students
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                      color: kShadow, blurRadius: 3, offset: Offset(1, 2)),
                ],
              ),
              child: TextField(
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: "Search students",
                  hintStyle: TextStyle(fontSize: 13),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                ),
                onChanged: (val) => setState(() => searchQuery = val),
              ),
            ),
          ),

          // Table Headers
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Container(
              decoration: BoxDecoration(
                color: kBackground,
                border: const Border(
                  bottom: BorderSide(color: kPrimary, width: 2),
                  top: BorderSide(color: kPrimary, width: 2),
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 6.0, horizontal: 16.0),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text("STUDENT ID",
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    const Expanded(
                      flex: 3,
                      child: Text("STUDENT NAME",
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500)),
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
                              else if (value == 'all_absent') _markAll(false);
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'all_present',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.green, size: 18),
                                    SizedBox(width: 8),
                                    Text('Mark All Present'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'all_absent',
                                child: Row(
                                  children: [
                                    Icon(Icons.cancel,
                                        color: Colors.red, size: 18),
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
            child: Stack(
              children: [
                filteredStudents.isEmpty
                    ? const Center(child: Text("No students found."))
                    : ListView.separated(
                        itemCount: filteredStudents.length,
                        separatorBuilder: (_, __) =>
                            Divider(color: kPrimary, height: 1, thickness: 0.7),
                        itemBuilder: (context, i) {
                          final s = filteredStudents[i];
                          final sid = s['id'];
                          final sname = s['name'];
                          final present = attendance[sid] ?? false;
                          final detectedViaBLE =
                              detectedStudentIds.contains(sid);

                          return Container(
                            color: detectedViaBLE
                                ? Colors.blue.shade50
                                : null, // Highlight BLE detected students
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8),
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              sid,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (detectedViaBLE) ...[
                                            SizedBox(width: 4),
                                            Icon(Icons.bluetooth_connected,
                                                color: Colors.blue, size: 12),
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
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (detectedViaBLE) ...[
                                          SizedBox(width: 4),
                                          Container(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 4, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.blue,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'AUTO',
                                              style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500),
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
                                        key: ValueKey(
                                            '${sid}_${present}_${detectedViaBLE}'), // Force rebuild with unique key
                                        value: present,
                                        activeColor: detectedViaBLE
                                            ? Colors.blue
                                            : Colors.green,
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
