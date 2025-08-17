import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';

class ClassControlPage extends StatefulWidget {
  final String className;
  final String departmentId;

  const ClassControlPage({
    Key? key,
    required this.className,
    required this.departmentId,
  }) : super(key: key);

  @override
  _ClassControlPageState createState() => _ClassControlPageState();
}

class _ClassControlPageState extends State<ClassControlPage> {
  final TextEditingController _facultyIdController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();

  String? _selectedSemester;
  String? selectedClassId;

  final List<String> _semesters = [
    'I',
    'II',
    'III',
    'IV',
    'V',
    'VI',
    'VII',
    'VIII',
    'IX',
    'X'
  ];

  List<Map<String, dynamic>> _facultyList = [];
  Map<String, String> _facultyNames = {};

  // semester time period
  DateTime? _semesterStartDate;
  DateTime? _semesterEndDate;

  DateTime? semesterStartDate;
  DateTime? semesterEndDate;

  // semester history
  Map<String, Map<String, dynamic>> _semesterHistory = {};
  Map<String, dynamic> _semesterHistoryFromKeys = {};
  String? _currentSemester;

  // Loading state
  bool _isLoadingSemesterHistory = true;
  bool _isLoadingFaculty = false;
  bool _isUploadingTimetable = false;

  // Timetable management
  final ImagePicker _imagePicker = ImagePicker();
  String? _currentTimetableUrl;
  Map<String, String> _semesterTimetables = {};

  // Firestore path parts
  final String collegePath = 'colleges';
  final String departmentsDoc = 'departments';
  final String allDepartmentsCollection = 'all_departments';
  final String classesCollection = 'clasees'; // Keeping your correct spelling

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _facultyIdController.dispose();
    _subjectController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          semesterStartDate = picked;
        } else {
          semesterEndDate = picked;
        }
      });
    }
  }

  Future<void> _saveSemesterDates(String classId) async {
    if (semesterStartDate == null || semesterEndDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select both start and end dates")),
      );
      return;
    }

    await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .update({
      'semesterStart': semesterStartDate!.toIso8601String(),
      'semesterEnd': semesterEndDate!.toIso8601String(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Semester dates updated successfully")),
    );
  }

  Future<void> _deleteClass() async {
    try {
      final classDocRef = await getClassDocRef();
      print("Deleting class document: ${classDocRef.path}");

      // Check if document exists before attempting deletion
      final docSnapshot = await classDocRef.get();
      if (!docSnapshot.exists) {
        _showSnackBar("Class document not found");
        return;
      }

      await classDocRef.delete();
      _showSnackBar("Class deleted successfully");
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint("Error deleting class: $e");
      _showSnackBar("Failed to delete class: $e");
    }
  }

  Future<void> _fetchAllFacultyNames() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("colleges")
          .doc("faculties")
          .collection("all_faculties")
          .get();

      final namesMap = <String, String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final id = doc.id;
        final name = (data['name'] ?? "Unknown").toString();
        namesMap[id] = name;
      }

      if (mounted) {
        setState(() {
          _facultyNames = namesMap;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch faculty names: $e");
      _showSnackBar("Failed to fetch faculty names: $e");
    }
  }

  Future<void> _initializeData() async {
    print("Initializing data for class: ${widget.className}, department: ${widget.departmentId}");
    await _fetchAllFacultyNames();
    await _ensureClassDocumentExists();
    await _fetchSemesterHistory();
  }

  Future<void> _ensureClassDocumentExists() async {
    try {
      final classDocRef = await getClassDocRef();
      final docSnapshot = await classDocRef.get();

      if (!docSnapshot.exists) {
        print("Creating class document for: ${widget.className}");
        // Create the document with basic structure
        await classDocRef.set({
          'className': widget.className,
          'departmentId': widget.departmentId,
          'createdAt': FieldValue.serverTimestamp(),
          'faculty': {},
          'semesterHistory': {},
          'timetables': {}, // Add timetables field
        });
        print("Class document created successfully");
      }
    } catch (e) {
      debugPrint("Error ensuring class document exists: $e");
      _showSnackBar("Error initializing class: $e");
    }
  }

  Future<DocumentReference> getClassDocRef() async {
    // Normalize class name to handle different formats
    String normalizedClassName = widget.className.trim();

    final docRef = FirebaseFirestore.instance
        .collection(collegePath)
        .doc(departmentsDoc)
        .collection(allDepartmentsCollection)
        .doc(widget.departmentId)
        .collection(classesCollection)
        .doc(normalizedClassName);

    print("Class document reference: ${docRef.path}");
    return docRef;
  }

  Future<void> _fetchSemesterHistory() async {
    if (!mounted) return;
    setState(() {
      _isLoadingSemesterHistory = true;
    });

    try {
      final classDocRef = await getClassDocRef();
      final snapshot = await classDocRef.get();

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>? ?? {};
        print("Fetched class data: $data");

        // Process semester history with better error handling
        final Map<String, Map<String, dynamic>> semesterHistoryProcessed = {};

        // 1) Handle canonical 'semesterHistory' field
        final semesterHistoryRaw = data['semesterHistory'];
        if (semesterHistoryRaw != null && semesterHistoryRaw is Map<String, dynamic>) {
          semesterHistoryRaw.forEach((k, v) {
            if (v is Map<String, dynamic>) {
              semesterHistoryProcessed[k] = Map<String, dynamic>.from(v);
            } else if (v != null) {
              // Handle non-map values
              semesterHistoryProcessed[k] = {'value': v};
            }
          });
        }

        // 2) Handle keys that start with "semesterHistory"
        final Map<String, dynamic> semesterHistoryFromKeys = {};
        data.forEach((key, value) {
          if (key.toString().startsWith("semesterHistory") && key != "semesterHistory") {
            semesterHistoryFromKeys[key] = value;
          }
        });

        // 3) Process and merge semesterHistoryFromKeys
        semesterHistoryFromKeys.forEach((rawKey, rawValue) {
          String normalizedKey = rawKey;
          if (normalizedKey.startsWith("semesterHistory.")) {
            normalizedKey = normalizedKey.split(".").last;
          } else if (normalizedKey.startsWith("semesterHistory_")) {
            normalizedKey = normalizedKey.split("_").last;
          } else if (normalizedKey.startsWith("semesterHistory")) {
            normalizedKey = normalizedKey.replaceFirst("semesterHistory", "");
          }
          normalizedKey = normalizedKey.trim();

          if (normalizedKey.isNotEmpty) {
            if (rawValue is Map<String, dynamic>) {
              semesterHistoryProcessed[normalizedKey] = Map<String, dynamic>.from(rawValue);
            } else if (rawValue != null) {
              semesterHistoryProcessed[normalizedKey] = {'value': rawValue};
            }
          }
        });

        // 4) Read currentSemester and timetables
        String? currentSemester;
        final currentSemesterRaw = data['currentSemester'];
        if (currentSemesterRaw != null) {
          if (currentSemesterRaw is String) {
            currentSemester = currentSemesterRaw;
          } else if (currentSemesterRaw is Map<String, dynamic>) {
            currentSemester = currentSemesterRaw['semester'] as String?;
          }
        }

        // Load timetables
        final Map<String, String> timetables = {};
        final timetablesData = data['timetables'] as Map<String, dynamic>?;
        if (timetablesData != null) {
          timetablesData.forEach((key, value) {
            if (value is String) {
              timetables[key] = value;
            }
          });
        }

        // Set current timetable if available
        String? currentTimetableUrl;
        if (currentSemester != null && timetables.containsKey(currentSemester)) {
          currentTimetableUrl = timetables[currentSemester];
        }

        if (mounted) {
          setState(() {
            _semesterHistory = semesterHistoryProcessed;
            _semesterHistoryFromKeys = semesterHistoryFromKeys;
            _currentSemester = currentSemester;
            _semesterTimetables = timetables;
            _currentTimetableUrl = currentTimetableUrl;
            _isLoadingSemesterHistory = false;
          });
        }
      } else {
        print("Class document does not exist, creating it...");
        await _ensureClassDocumentExists();

        if (mounted) {
          setState(() {
            _semesterHistory = {};
            _semesterHistoryFromKeys = {};
            _currentSemester = null;
            _semesterTimetables = {};
            _currentTimetableUrl = null;
            _isLoadingSemesterHistory = false;
          });
        }
      }
    } catch (e, st) {
      if (mounted) {
        setState(() {
          _isLoadingSemesterHistory = false;
        });
      }
      debugPrint("Error fetching semester history: $e\n$st");
      _showSnackBar("Failed to fetch semester history: $e");
    }
  }

  Future<void> _fetchFaculty() async {
    if (_selectedSemester == null) return;

    setState(() {
      _isLoadingFaculty = true;
    });

    try {
      final docRef = await getClassDocRef();
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        await _ensureClassDocumentExists();
        if (mounted) {
          setState(() {
            _facultyList = [];
            _isLoadingFaculty = false;
          });
        }
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final facultyMap = data['faculty'] as Map<String, dynamic>? ?? {};
      final semesterFaculty = facultyMap[_selectedSemester] as List<dynamic>? ?? [];

      final list = semesterFaculty.map((e) {
        if (e is Map<String, dynamic>) return Map<String, dynamic>.from(e);
        return <String, dynamic>{};
      }).toList();

      if (mounted) {
        setState(() {
          _facultyList = list;
          _isLoadingFaculty = false;
        });
      }
    } catch (e, st) {
      if (mounted) setState(() => _isLoadingFaculty = false);
      debugPrint("Error fetching faculty: $e\n$st");
      _showSnackBar("Failed to fetch faculty: $e");
    }
  }

  Future<void> _setCurrentSemester(String semester) async {
    setState(() {
      _selectedSemester = semester;
    });
    await _fetchFaculty();
    await _showSemesterTimeDialog();
  }

  Future<void> _setExistingSemesterAsCurrent(String semester) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Setting current semester..."),
            ],
          ),
        ),
      );

      final classDocRef = await getClassDocRef();
      final semesterData = _semesterHistory[semester];

      if (semesterData != null) {
        await classDocRef.set({
          'currentSemester': {
            'semester': semester,
            'startDate': semesterData['startDate'],
            'endDate': semesterData['endDate'],
            'updatedAt': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));

        // Update students with better error handling
        await _updateStudentsForClass(semester, semesterData);

        setState(() {
          _currentSemester = semester;
          _selectedSemester = semester;
        });

        if (Navigator.canPop(context)) Navigator.pop(context);
        await _fetchFaculty();
        _showSnackBar("✅ Semester $semester set as current successfully");
      } else {
        if (Navigator.canPop(context)) Navigator.pop(context);
        _showSnackBar("No data found for semester $semester");
      }
    } catch (e, st) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      debugPrint("Error setting existing semester: $e\n$st");
      _showSnackBar("Failed to set current semester: $e");
    }
  }

  Future<void> _updateStudentsForClass(String semester, Map<String, dynamic> semesterData) async {
    try {
      // Create a more comprehensive query strategy
      final studentQueries = [
        // Query with exact class name match
        FirebaseFirestore.instance
            .collection("colleges")
            .doc("students")
            .collection("all_students")
            .where("class", isEqualTo: widget.className)
            .where("departmentId", isEqualTo: widget.departmentId),

        // Query with className field
        FirebaseFirestore.instance
            .collection("colleges")
            .doc("students")
            .collection("all_students")
            .where("className", isEqualTo: widget.className)
            .where("departmentId", isEqualTo: widget.departmentId),

        // Query with lowercase class name
        FirebaseFirestore.instance
            .collection("colleges")
            .doc("students")
            .collection("all_students")
            .where("class", isEqualTo: widget.className.toLowerCase())
            .where("departmentId", isEqualTo: widget.departmentId),

        // Query with uppercase class name
        FirebaseFirestore.instance
            .collection("colleges")
            .doc("students")
            .collection("all_students")
            .where("class", isEqualTo: widget.className.toUpperCase())
            .where("departmentId", isEqualTo: widget.departmentId),

        // Additional queries for different field combinations
        FirebaseFirestore.instance
            .collection("colleges")
            .doc("students")
            .collection("all_students")
            .where("className", isEqualTo: widget.className.toLowerCase())
            .where("departmentId", isEqualTo: widget.departmentId),

        FirebaseFirestore.instance
            .collection("colleges")
            .doc("students")
            .collection("all_students")
            .where("className", isEqualTo: widget.className.toUpperCase())
            .where("departmentId", isEqualTo: widget.departmentId),
      ];

      Set<String> processedStudentIds = {};
      int totalUpdatedStudents = 0;

      for (final query in studentQueries) {
        try {
          final studentsSnapshot = await query.get();

          if (studentsSnapshot.docs.isEmpty) {
            continue;
          }

          // Process in batches to avoid Firestore limits
          final batch = FirebaseFirestore.instance.batch();
          int batchCount = 0;

          for (var studentDoc in studentsSnapshot.docs) {
            // Skip if already processed
            if (processedStudentIds.contains(studentDoc.id)) {
              continue;
            }

            processedStudentIds.add(studentDoc.id);

            // Update student document
            batch.update(studentDoc.reference, {
              'currentSemester': semester,
              'semesterStartDate': semesterData['startDate'],
              'semesterEndDate': semesterData['endDate'],
              'semesterUpdatedAt': FieldValue.serverTimestamp(),
              'lastUpdatedBy': 'classControl', // Add tracking
            });

            batchCount++;

            // Commit batch if it reaches 500 (Firestore limit)
            if (batchCount >= 500) {
              await batch.commit();
              totalUpdatedStudents += batchCount;
              batchCount = 0;
            }
          }

          // Commit remaining batch
          if (batchCount > 0) {
            await batch.commit();
            totalUpdatedStudents += batchCount;
          }

        } catch (queryError) {
          debugPrint("Query error: $queryError");
          // Continue with next query even if one fails
        }
      }

      if (totalUpdatedStudents > 0) {
        _showSnackBar("✅ Updated $totalUpdatedStudents students for semester $semester");
      } else {
        _showSnackBar("⚠️ No students found matching class: ${widget.className}");

        // Debug: Show what we're looking for
        debugPrint("Searching for students with:");
        debugPrint("- class: ${widget.className}");
        debugPrint("- departmentId: ${widget.departmentId}");
      }

    } catch (e, stackTrace) {
      debugPrint("Error updating students: $e\n$stackTrace");
      _showSnackBar("❌ Failed to update students: ${e.toString()}");
    }
  }

  Future<void> _showSemesterTimeDialog() async {
    DateTime? startDate;
    DateTime? endDate;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: _buildDialogHeader(
                "Set Semester Time Period", () => Navigator.pop(context)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Semester: ${_selectedSemester ?? ''}",
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  ListTile(
                    title: Text(
                      "Start Date: ${_formatDate(startDate)}",
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => startDate = picked);
                      }
                    },
                  ),
                  ListTile(
                    title: Text(
                      "End Date: ${_formatDate(endDate)}",
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: startDate ?? DateTime.now(),
                        firstDate: startDate ?? DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setDialogState(() => endDate = picked);
                      }
                    },
                  )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: startDate != null && endDate != null
                    ? () {
                  _semesterStartDate = startDate;
                  _semesterEndDate = endDate;
                  Navigator.pop(context);
                  _updateSemesterForAllStudents();
                }
                    : null,
                child: const Text("Update"),
              ),
            ],
          );
        });
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return "Not selected";
    return "${date.day}/${date.month}/${date.year}";
  }

  Future<void> _updateSemesterForAllStudents() async {
    if (_selectedSemester == null || _semesterStartDate == null || _semesterEndDate == null) {
      _showSnackBar("Please select semester and time period first");
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text("Updating semester $_selectedSemester..."),
              const SizedBox(height: 8),
              const Text("This may take a moment", style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      );

      final classDocRef = await getClassDocRef();

      // Prepare semester data
      final semesterData = {
        'semester': _selectedSemester,
        'startDate': Timestamp.fromDate(_semesterStartDate!),
        'endDate': Timestamp.fromDate(_semesterEndDate!),
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Update class document with both current semester and history
      await classDocRef.set({
        'currentSemester': {
          'semester': _selectedSemester,
          'startDate': Timestamp.fromDate(_semesterStartDate!),
          'endDate': Timestamp.fromDate(_semesterEndDate!),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'semesterHistory.$_selectedSemester': semesterData,
        // Also update the metadata
        'lastModified': FieldValue.serverTimestamp(),
        'className': widget.className,
        'departmentId': widget.departmentId,
      }, SetOptions(merge: true));

      // Update all students for this class
      await _updateStudentsForClass(_selectedSemester!, {
        'startDate': Timestamp.fromDate(_semesterStartDate!),
        'endDate': Timestamp.fromDate(_semesterEndDate!),
      });

      // Close loading dialog
      if (Navigator.canPop(context)) Navigator.pop(context);

      // Update local state
      setState(() {
        _currentSemester = _selectedSemester;
      });

      // Refresh data to show changes
      await _fetchSemesterHistory();

      _showSnackBar("✅ Semester $_selectedSemester set as current successfully");

    } catch (e, stackTrace) {
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) Navigator.pop(context);

      debugPrint("Error updating students: $e\n$stackTrace");
      _showSnackBar("❌ Failed to update semester: ${e.toString()}");
    }
  }

  // Enhanced debug method for verification
  Future<void> _verifyStudentClassMapping() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Verifying student data..."),
            ],
          ),
        ),
      );

      // Get all students and check their class assignments
      final allStudentsSnapshot = await FirebaseFirestore.instance
          .collection("colleges")
          .doc("students")
          .collection("all_students")
          .get();

      Map<String, List<String>> classStudentMap = {};
      int totalStudents = 0;
      int studentsWithClass = 0;
      int studentsWithClassName = 0;
      int studentsMatchingThisClass = 0;

      for (var doc in allStudentsSnapshot.docs) {
        final data = doc.data();
        totalStudents++;

        // Check different class field variations
        final classField = data['class']?.toString();
        final classNameField = data['className']?.toString();
        final departmentField = data['departmentId']?.toString() ?? data['department']?.toString();

        if (classField != null) {
          studentsWithClass++;
          if (!classStudentMap.containsKey(classField)) {
            classStudentMap[classField] = [];
          }
          classStudentMap[classField]!.add(doc.id);

          // Check if this matches our current class
          if ((classField == widget.className ||
              classField == widget.className.toLowerCase() ||
              classField == widget.className.toUpperCase()) &&
              departmentField == widget.departmentId) {
            studentsMatchingThisClass++;
          }
        }

        if (classNameField != null) {
          studentsWithClassName++;

          // Check if this matches our current class
          if ((classNameField == widget.className ||
              classNameField == widget.className.toLowerCase() ||
              classNameField == widget.className.toUpperCase()) &&
              departmentField == widget.departmentId) {
            studentsMatchingThisClass++;
          }
        }
      }

      if (Navigator.canPop(context)) Navigator.pop(context);

      // Show verification results
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Student Data Verification"),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Total students in database: $totalStudents"),
                Text("Students with 'class' field: $studentsWithClass"),
                Text("Students with 'className' field: $studentsWithClassName"),
                const SizedBox(height: 10),
                Text("Students matching '${widget.className}' in '${widget.departmentId}': $studentsMatchingThisClass",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                const Text("Classes found in database:",
                    style: TextStyle(fontWeight: FontWeight.bold)),
                ...classStudentMap.entries.map((entry) =>
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text("${entry.key}: ${entry.value.length} students"),
                    )
                ).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
          ],
        ),
      );

    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showSnackBar("Verification failed: $e");
    }
  }

  // Debug method for specific student
  Future<void> _debugSpecificStudent(String studentId) async {
    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection("colleges")
          .doc("students")
          .collection("all_students")
          .doc(studentId)
          .get();

      if (studentDoc.exists) {
        final data = studentDoc.data()!;
        debugPrint("=== STUDENT $studentId DEBUG ===");
        debugPrint("All fields: ${data.keys.toList()}");
        debugPrint("class: '${data['class']}'");
        debugPrint("className: '${data['className']}'");
        debugPrint("department: '${data['department']}'");
        debugPrint("departmentId: '${data['departmentId']}'");
        debugPrint("currentSemester: '${data['currentSemester']}'");
        debugPrint("Looking for class: '${widget.className}'");
        debugPrint("Looking for department: '${widget.departmentId}'");
        debugPrint("=== END DEBUG ===");

        _showSnackBar("Check console for student data debug info");
      } else {
        debugPrint("Student $studentId not found");
        _showSnackBar("Student $studentId not found");
      }
    } catch (e) {
      debugPrint("Error debugging student: $e");
      _showSnackBar("Debug error: $e");
    }
  }

  Future<void> _addFaculty() async {
    final facultyId = _facultyIdController.text.trim();
    final subject = _subjectController.text.trim();

    if (_selectedSemester == null || facultyId.isEmpty || subject.isEmpty) {
      _showSnackBar("All fields are required");
      return;
    }

    try {
      final docRef = await getClassDocRef();
      final snapshot = await docRef.get();
      final data = snapshot.exists ? snapshot.data() as Map<String, dynamic> : {};

      Map<String, dynamic> facultyMap = data['faculty'] != null
          ? Map<String, dynamic>.from(data['faculty'] as Map<String, dynamic>)
          : {};

      List<dynamic> semesterFaculty = facultyMap[_selectedSemester] != null
          ? List<dynamic>.from(facultyMap[_selectedSemester] as List<dynamic>)
          : [];

      final duplicate = semesterFaculty.any((f) {
        if (f is Map<String, dynamic>) {
          return f['facultyId'] == facultyId && f['subject'] == subject;
        }
        return false;
      });

      if (duplicate) {
        _showSnackBar("Faculty with this subject already exists in selected semester");
        return;
      }

      // ✅ Use client timestamp instead of serverTimestamp
      semesterFaculty.add({
        'facultyId': facultyId,
        'subject': subject,
        'addedAt': DateTime.now().toIso8601String(),
      });

      facultyMap[_selectedSemester!] = semesterFaculty;

      await docRef.set({'faculty': facultyMap}, SetOptions(merge: true));

      _facultyIdController.clear();
      _subjectController.clear();

      _showSnackBar("Faculty added successfully");
      await _fetchFaculty();
    } catch (e, st) {
      debugPrint("Error adding faculty: $e\n$st");
      _showSnackBar("Failed to add faculty: $e");
    }
  }

  Future<void> _removeFaculty(String facultyId, String subject) async {
    if (_selectedSemester == null) return;

    try {
      final docRef = await getClassDocRef();
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> facultyMap = data['faculty'] != null
          ? Map<String, dynamic>.from(data['faculty'] as Map<String, dynamic>)
          : {};

      List<dynamic> semesterFaculty = facultyMap[_selectedSemester] != null
          ? List<dynamic>.from(facultyMap[_selectedSemester] as List<dynamic>)
          : [];

      semesterFaculty.removeWhere((f) {
        if (f is Map<String, dynamic>) {
          return f['facultyId'] == facultyId && f['subject'] == subject;
        }
        return false;
      });

      facultyMap[_selectedSemester!] = semesterFaculty;
      await docRef.set({'faculty': facultyMap}, SetOptions(merge: true));

      _showSnackBar("Faculty removed successfully");
      await _fetchFaculty();
    } catch (e, st) {
      debugPrint("Error removing faculty: $e\n$st");
      _showSnackBar("Failed to remove faculty: $e");
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildDialogHeader(String title, VoidCallback onClose) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFF7F50),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onClose),
        ],
      ),
    );
  }

  void _showAddFacultyDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: _buildDialogHeader("Add Faculty & Subject", () => Navigator.pop(context)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedSemester,
                    hint: const Text("Select Semester"),
                    items: _semesters
                        .map((sem) => DropdownMenuItem(value: sem, child: Text(sem)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSemester = val;
                      });
                    },
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _facultyIdController,
                    decoration: const InputDecoration(labelText: "Faculty ID"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(labelText: "Subject"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _facultyIdController.clear();
                  _subjectController.clear();
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _addFaculty();
                  Navigator.pop(context);
                },
                child: const Text("Add"),
              ),
            ],
          ),
        );
      },
    );
  }

  // UPDATED TIMETABLE METHODS - FIXED FOR ANY SIZE & BACKEND STORAGE

  // Updated _pickTimetableImage method - NO SIZE RESTRICTIONS
  Future<void> _pickTimetableImage() async {
    if (_selectedSemester == null) {
      _showSnackBar("Please select a semester first");
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        // REMOVED ALL SIZE RESTRICTIONS - Accept any size
        imageQuality: 85, // Keep good quality
      );

      if (image != null) {
        await _uploadTimetableImage(File(image.path));
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      _showSnackBar("Failed to pick image: $e");
    }
  }

  // Updated _uploadTimetableImage method - FIXED STORAGE ERRORS & BACKEND UPDATE
  Future<void> _uploadTimetableImage(File imageFile) async {
    if (_selectedSemester == null) return;

    setState(() {
      _isUploadingTimetable = true;
    });

    try {
      // Show upload progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text("Uploading timetable for semester $_selectedSemester..."),
              const SizedBox(height: 8),
              const Text("Accepting any image size", style: TextStyle(fontSize: 12, color: Colors.green)),
            ],
          ),
        ),
      );

      // SIMPLIFIED STORAGE PATH - More reliable
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('timetables')
          .child('${widget.departmentId}_${widget.className}_semester_$_selectedSemester.jpg');

      // SIMPLIFIED UPLOAD - Remove complex metadata that might cause errors
      try {
        // Delete existing file first to avoid conflicts
        try {
          await storageRef.delete();
        } catch (deleteError) {
          // File might not exist, that's okay
          debugPrint("Previous file delete (expected): $deleteError");
        }

        // Simple upload without complex metadata
        final uploadTask = await storageRef.putFile(imageFile);
        final downloadUrl = await uploadTask.ref.getDownloadURL();

        // UPDATE FIRESTORE WITH TIMETABLE URL IN BACKEND - MULTIPLE LOCATIONS
        final classDocRef = await getClassDocRef();

        final updateData = <String, dynamic>{
          // Main timetables collection
          'timetables.$_selectedSemester': downloadUrl,

          // Also store in semester history for complete data
          'semesterHistory.$_selectedSemester.timetableUrl': downloadUrl,
          'semesterHistory.$_selectedSemester.timetableUpdatedAt': FieldValue.serverTimestamp(),

          // Global timetable info
          'currentTimetableUrl': _selectedSemester == _currentSemester ? downloadUrl : null,
          'lastModified': FieldValue.serverTimestamp(),

          // Add metadata for tracking
          'timetableInfo': {
            'lastUploadedSemester': _selectedSemester,
            'lastUploadTime': FieldValue.serverTimestamp(),
            'totalTimetables': (_semesterTimetables.length + 1),
          }
        };

        await classDocRef.set(updateData, SetOptions(merge: true));

        debugPrint("✅ Timetable URL stored in Firestore: $downloadUrl");
        debugPrint("✅ Updated semester: $_selectedSemester");

        // Update local state
        setState(() {
          _semesterTimetables[_selectedSemester!] = downloadUrl;
          if (_selectedSemester == _currentSemester) {
            _currentTimetableUrl = downloadUrl;
          }
          _isUploadingTimetable = false;
        });

        // Close upload dialog
        if (Navigator.canPop(context)) Navigator.pop(context);

        _showSnackBar("✅ Timetable uploaded successfully (Any size supported)");

      } catch (uploadError) {
        throw Exception("Upload failed: ${uploadError.toString()}");
      }

    } catch (e, stackTrace) {
      setState(() {
        _isUploadingTimetable = false;
      });

      // Close upload dialog if open
      if (Navigator.canPop(context)) Navigator.pop(context);

      debugPrint("Error uploading timetable: $e\n$stackTrace");

      // BETTER ERROR HANDLING
      String errorMessage = "Upload failed";

      if (e.toString().toLowerCase().contains('network')) {
        errorMessage = "Network error - Check internet connection";
      } else if (e.toString().toLowerCase().contains('permission')) {
        errorMessage = "Permission denied - Check app permissions";
      } else if (e.toString().toLowerCase().contains('storage')) {
        errorMessage = "Storage error - Try again in a moment";
      } else if (e.toString().toLowerCase().contains('quota')) {
        errorMessage = "Storage quota exceeded";
      } else if (e.toString().toLowerCase().contains('unauthorized')) {
        errorMessage = "Authentication error - Please re-login";
      } else {
        errorMessage = "Upload failed - Please try again";
      }

      _showSnackBar("❌ $errorMessage");

      // Show detailed error in debug mode
      if (e.toString().isNotEmpty) {
        debugPrint("Detailed error: ${e.toString()}");
      }
    }
  }

  // Updated _deleteTimetable method - FIXED FOR SIMPLIFIED STORAGE PATH & BACKEND
  Future<void> _deleteTimetable() async {
    if (_selectedSemester == null || !_semesterTimetables.containsKey(_selectedSemester)) {
      return;
    }

    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Delete Timetable"),
          content: Text("Are you sure you want to delete the timetable for semester $_selectedSemester?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      setState(() {
        _isUploadingTimetable = true;
      });

      // Show delete progress dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Deleting timetable..."),
            ],
          ),
        ),
      );

      // UPDATED STORAGE PATH - Match the upload path
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('timetables')
          .child('${widget.departmentId}_${widget.className}_semester_$_selectedSemester.jpg');

      // Delete from storage
      try {
        await storageRef.delete();
      } catch (storageError) {
        debugPrint("Storage delete error (file might not exist): $storageError");
        // Continue with Firestore update even if storage delete fails
      }

      // UPDATE FIRESTORE - Remove timetable from multiple locations
      final classDocRef = await getClassDocRef();

      final updateData = <String, dynamic>{
        // Remove from main timetables collection
        'timetables.$_selectedSemester': FieldValue.delete(),

        // Remove from semester history
        'semesterHistory.$_selectedSemester.timetableUrl': FieldValue.delete(),
        'semesterHistory.$_selectedSemester.timetableUpdatedAt': FieldValue.delete(),

        // Update global info
        'lastModified': FieldValue.serverTimestamp(),
      };

      // Clear current timetable if this was the current semester
      if (_selectedSemester == _currentSemester) {
        updateData['currentTimetableUrl'] = FieldValue.delete();
      }

      await classDocRef.update(updateData);

      debugPrint("✅ Timetable removed from Firestore for semester: $_selectedSemester");

      // Update local state
      setState(() {
        _semesterTimetables.remove(_selectedSemester);
        if (_selectedSemester == _currentSemester) {
          _currentTimetableUrl = null;
        }
        _isUploadingTimetable = false;
      });

      // Close delete dialog
      if (Navigator.canPop(context)) Navigator.pop(context);

      _showSnackBar("✅ Timetable deleted successfully");

    } catch (e, stackTrace) {
      setState(() {
        _isUploadingTimetable = false;
      });

      // Close delete dialog if open
      if (Navigator.canPop(context)) Navigator.pop(context);

      debugPrint("Error deleting timetable: $e\n$stackTrace");
      _showSnackBar("❌ Failed to delete timetable: ${e.toString()}");
    }
  }

  // Updated timetable display - supports any ratio
  Widget _buildTimetablePreview(String imageUrl) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        maxHeight: 300, // Increased max height
        minHeight: 150,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.contain, // Changed from BoxFit.cover to contain - preserves aspect ratio
          placeholder: (context, url) => const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 8),
                Text("Loading...", style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          errorWidget: (context, url, error) => const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red),
              SizedBox(height: 4),
              Text("Failed to load", style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  // Updated _showTimetableDialog method
  Future<void> _showTimetableDialog() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: _buildDialogHeader(
            "Class Timetable",
                () => Navigator.pop(context)
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_selectedSemester == null)
                const Text(
                  "Please select a semester first",
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                )
              else ...[
                Text(
                  "Semester: $_selectedSemester",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),

                // Current timetable display - UPDATED SECTION
                if (_semesterTimetables.containsKey(_selectedSemester)) ...[
                  const Text("Current Timetable:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildTimetablePreview(_semesterTimetables[_selectedSemester]!), // Using new method
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey[50],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.schedule, size: 48, color: Colors.grey),
                        SizedBox(height: 8),
                        Text("No timetable uploaded", style: TextStyle(color: Colors.grey)),
                        SizedBox(height: 4),
                        Text("Any image size supported", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploadingTimetable ? null : () {
                          Navigator.pop(context);
                          _pickTimetableImage();
                        },
                        icon: _isUploadingTimetable
                            ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)
                        )
                            : const Icon(Icons.upload),
                        label: Text(_isUploadingTimetable
                            ? "Uploading..."
                            : _semesterTimetables.containsKey(_selectedSemester)
                            ? "Replace" : "Upload"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF7F50),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    if (_semesterTimetables.containsKey(_selectedSemester)) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isUploadingTimetable ? null : () {
                            Navigator.pop(context);
                            _deleteTimetable();
                          },
                          icon: const Icon(Icons.delete),
                          label: const Text("Delete"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (_semesterTimetables.containsKey(_selectedSemester))
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _viewFullTimetable();
              },
              icon: const Icon(Icons.fullscreen),
              label: const Text("View Full"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  void _viewFullTimetable() {
    if (_selectedSemester == null || !_semesterTimetables.containsKey(_selectedSemester)) {
      return;
    }

    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => _FullTimetableView(
    //       imageUrl: _semesterTimetables[_selectedSemester]!,
    //       semester: _selectedSemester!,
    //       className: widget.className,
    //     ),
    //   ),
    // );
  }

  // Add this method to verify backend updates
  Future<void> _verifyTimetableInBackend() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Checking backend data..."),
            ],
          ),
        ),
      );

      final classDocRef = await getClassDocRef();
      final snapshot = await classDocRef.get();

      if (Navigator.canPop(context)) Navigator.pop(context);

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;

        // Extract timetable data
        final timetables = data['timetables'] as Map<String, dynamic>? ?? {};
        final semesterHistory = data['semesterHistory'] as Map<String, dynamic>? ?? {};
        final currentTimetableUrl = data['currentTimetableUrl'];

        // Show verification results
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Backend Timetable Verification"),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("TIMETABLES COLLECTION:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...timetables.entries.map((entry) =>
                      Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: Text("Semester ${entry.key}: ${entry.value != null ? '✅ URL Stored' : '❌ Missing'}"),
                      )
                  ).toList(),

                  const SizedBox(height: 15),
                  const Text("SEMESTER HISTORY:", style: TextStyle(fontWeight: FontWeight.bold)),
                  ...semesterHistory.entries.map((entry) {
                    final semData = entry.value as Map<String, dynamic>? ?? {};
                    final hasUrl = semData.containsKey('timetableUrl');
                    return Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: Text("Semester ${entry.key}: ${hasUrl ? '✅ URL in History' : '❌ No URL'}"),
                    );
                  }).toList(),

                  const SizedBox(height: 15),
                  Text("CURRENT TIMETABLE URL: ${currentTimetableUrl != null ? '✅ Set' : '❌ Not Set'}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),

                  const SizedBox(height: 10),
                  const Text("RAW DATA:", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("Timetables: ${timetables.keys.toList()}", style: const TextStyle(fontSize: 12)),
                  Text("Total stored: ${timetables.length}", style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Verification Failed"),
            content: const Text("Class document not found in backend"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showSnackBar("Verification failed: $e");
      debugPrint("Backend verification error: $e");
    }
  }

  Future<void> _refreshData() async {
    await _fetchSemesterHistory();
    if (_selectedSemester != null) {
      await _fetchFaculty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(70),
          child: AppBar(
            backgroundColor: const Color(0xFFFF7F50),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text("${widget.className.toUpperCase()} CLASS CONTROL",
                style: const TextStyle(color: Colors.white)),
            centerTitle: true,
            actions: [
              // ADDED BACKEND VERIFICATION BUTTON
              IconButton(
                icon: const Icon(Icons.cloud_sync, color: Colors.white),
                onPressed: _verifyTimetableInBackend,
                tooltip: "Verify Backend Data",
              ),
              IconButton(
                icon: const Icon(Icons.bug_report, color: Colors.white),
                onPressed: _verifyStudentClassMapping,
                tooltip: "Debug Student Data",
              ),
              IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  onPressed: _refreshData),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  switch (value) {
                    case 'debug_student':
                    // Example: Debug the specific student from your image
                      _debugSpecificStudent('sec23cj026');
                      break;
                    case 'delete_class':
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text("Delete Class"),
                            content: const Text(
                                "Are you sure you want to delete this class? This action cannot be undone."),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel"),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _deleteClass();
                                },
                                child: const Text("Delete"),
                              ),
                            ],
                          );
                        },
                      );
                      break;
                  }
                },
                itemBuilder: (BuildContext context) => [
                  const PopupMenuItem<String>(
                    value: 'debug_student',
                    child: Row(
                      children: [
                        Icon(Icons.person_search),
                        SizedBox(width: 8),
                        Text('Debug Student'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete_class',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Class'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        body: SafeArea(
          child: Column(
            children: [
              // Semester selector + Add button + Timetable button
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                Row(
                children: [
                Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedSemester,
                  hint: const Text("Select Semester"),
                  items: _semesters
                      .map((sem) => DropdownMenuItem(value: sem, child: Text(sem)))
                      .toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedSemester = val;
                    });
                    _fetchFaculty();
                  },
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(40)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _showAddFacultyDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: const Text("Add Faculty"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF7F50),
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Timetable section
          Row(
            children: [
          Expanded(
          child: ElevatedButton.icon(
          onPressed: _selectedSemester == null ? null : _showTimetableDialog,
            icon: const Icon(Icons.schedule),
            label: const Text("Manage Timetable"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            ),
          ),
          ),
              if (_selectedSemester != null && _semesterTimetables.containsKey(_selectedSemester)) ...[
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text("Uploaded", style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ],
          ),
                  ],
                ),
              ),

              // Main content
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refreshData,
                  child: ListView(
                    padding: EdgeInsets.only(
                      bottom: 90 + MediaQuery.of(context).padding.bottom, // Add padding for bottom nav
                    ),
                    children: [
                      if (selectedClassId != null) ...[
                        const SizedBox(height: 20),
                        Text("Semester Start: ${semesterStartDate != null ? semesterStartDate!.toLocal().toString().split(' ')[0] : 'Not set'}"),
                        ElevatedButton(
                          onPressed: () => _pickDate(true),
                          child: const Text("Edit Start Date"),
                        ),
                        const SizedBox(height: 10),
                        Text("Semester End: ${semesterEndDate != null ? semesterEndDate!.toLocal().toString().split(' ')[0] : 'Not set'}"),
                        ElevatedButton(
                          onPressed: () => _pickDate(false),
                          child: const Text("Edit End Date"),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () => _saveSemesterDates(selectedClassId!),
                          child: const Text("Save Dates"),
                        ),
                      ],

                      // Semester history container
                      Container(
                        margin: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 5,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: const BoxDecoration(
                                color: Color(0xFF36454F),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.history, color: Colors.white, size: 20),
                                  SizedBox(width: 8),
                                  Text("SEMESTER HISTORY",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                ],
                              ),
                            ),
                            if (_isLoadingSemesterHistory)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(width: 12),
                                          Text("Loading semester history...")
                                        ])),
                              )
                            else if (_semesterHistory.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text("No semester history found"))
                            else
                              Column(
                                children: _semesterHistory.keys.map((semester) {
                                  final semesterData = _semesterHistory[semester]!;
                                  final startDate =
                                  (semesterData['startDate'] as Timestamp?)?.toDate();
                                  final endDate =
                                  (semesterData['endDate'] as Timestamp?)?.toDate();
                                  final isCurrentSemester = _currentSemester == semester;

                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    color: isCurrentSemester
                                        ? const Color(0xFFFF7F50).withOpacity(0.1)
                                        : null,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 2,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text("Semester $semester",
                                                      style: TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                          color: isCurrentSemester
                                                              ? const Color(0xFFFF7F50)
                                                              : Colors.black87)),
                                                  if (isCurrentSemester) ...[
                                                    const SizedBox(width: 8),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(
                                                          horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                          color: const Color(0xFFFF7F50),
                                                          borderRadius:
                                                          BorderRadius.circular(10)),
                                                      child: const Text("CURRENT",
                                                          style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              if (startDate != null && endDate != null)
                                                Text(
                                                    "${startDate.day}/${startDate.month}/${startDate.year} - ${endDate.day}/${endDate.month}/${endDate.year}",
                                                    style: TextStyle(
                                                        color: Colors.grey[600],
                                                        fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        ElevatedButton(
                                          onPressed: isCurrentSemester
                                              ? null
                                              : () => _setExistingSemesterAsCurrent(semester),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isCurrentSemester
                                                ? const Color(0xFFFF7F50)
                                                : Colors.green,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                          ),
                                          child: Text(
                                              isCurrentSemester ? "Current" : "Set Current",
                                              style: const TextStyle(fontSize: 12)),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        ),
                      ),

                      // Add new semester buttons
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text("ADD NEW SEMESTER:",
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87)),
                          const SizedBox(height: 12),
                          Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _semesters.map((semester) {
                                final alreadyExists = _semesterHistory.containsKey(semester);
                                return ElevatedButton(
                                  onPressed: alreadyExists
                                      ? null
                                      : () => _setCurrentSemester(semester),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: alreadyExists
                                        ? Colors.grey[300]
                                        : (_selectedSemester == semester
                                        ? const Color(0xFFFF7F50)
                                        : Colors.blue[100]),
                                    foregroundColor: alreadyExists
                                        ? Colors.grey[600]
                                        : (_selectedSemester == semester
                                        ? Colors.white
                                        : Colors.black87),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 8),
                                    minimumSize: const Size(50, 36),
                                  ),
                                  child: Text(semester,
                                      style: const TextStyle(
                                          fontSize: 14, fontWeight: FontWeight.bold)),
                                );
                              }).toList()),
                          if (_semesterHistory.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                  "Note: Disabled buttons are semesters that already exist",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic)),
                            ),
                        ]),
                      ),

                      const SizedBox(height: 10),

                      // Faculty information header
                      Container(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          color: const Color(0xFF36454F),
                          child: const Text("FACULTY INFORMATION",
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.bold))),
                      Container(
                          color: Colors.black12,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: const Row(children: [
                            Expanded(flex: 3, child: Text("FACULTY NAME")),
                            Expanded(flex: 3, child: Text("SUBJECT")),
                            Expanded(flex: 1, child: Center(child: Text("REMOVE")))
                          ])),

                      // Faculty list
                      _isLoadingFaculty
                          ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()))
                          : _facultyList.isEmpty
                          ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: Text("No faculty found")))
                          : Column(
                        children: _facultyList.map((faculty) {
                          final facultyId =
                          (faculty['facultyId'] ?? "Unknown").toString();
                          final subject =
                          (faculty['subject'] ?? "Unknown").toString();
                          final facultyName = _facultyNames[facultyId] ?? facultyId;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                                border: Border(
                                    bottom: BorderSide(
                                        color: Colors.orange, width: 1))),
                            child: Row(children: [
                              Expanded(flex: 3, child: Text(facultyName)),
                              Expanded(flex: 3, child: Text(subject)),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _removeFaculty(facultyId, subject)),
                                ),
                              ),
                            ]),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      bottomNavigationBar: Container(
        height: 70 + MediaQuery.of(context).padding.bottom,
        decoration: const BoxDecoration(
            color: Color(0xFFE5E5E5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
        child: SafeArea(
          minimum: EdgeInsets.zero,
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  IconButton(
                      icon: Image.asset("assets/search.png", height: 26),
                      onPressed: () {}
                  ),
                  IconButton(
                      icon: Image.asset("assets/homeLogo.png", height: 32),
                      onPressed: () => Navigator.pop(context)
                  ),
                  IconButton(
                      icon: Image.asset("assets/account.png", height: 26),
                      onPressed: () {}
                  ),
                ]
            ),
          ),
        ),
      ),
    );
  }
}