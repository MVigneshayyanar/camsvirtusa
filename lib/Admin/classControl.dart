import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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


  // semester history
  Map<String, Map<String, dynamic>> _semesterHistory = {};
  Map<String, dynamic> _semesterHistoryFromKeys = {};
  String? _currentSemester;

  // Loading state
  bool _isLoadingSemesterHistory = true;
  bool _isLoadingFaculty = false;

  // Firestore path parts
  final String collegePath = 'colleges';
  final String departmentsDoc = 'departments';
  final String allDepartmentsCollection = 'all_departments';
  final String classesCollection = 'clasees'; // Keep your spelling

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
      Navigator.pop(context);
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
        });
        print("Class document created successfully");
      }
    } catch (e) {
      debugPrint("Error ensuring class document exists: $e");
      _showSnackBar("Error initializing class: $e");
    }
  }

  Future<DocumentReference> getClassDocRef() {
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
    return Future.value(docRef);
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

        // 4) Read currentSemester
        String? currentSemester;
        final currentSemesterRaw = data['currentSemester'];
        if (currentSemesterRaw != null) {
          if (currentSemesterRaw is String) {
            currentSemester = currentSemesterRaw;
          } else if (currentSemesterRaw is Map<String, dynamic>) {
            currentSemester = currentSemesterRaw['semester'] as String?;
          }
        }

        if (mounted) {
          setState(() {
            _semesterHistory = semesterHistoryProcessed;
            _semesterHistoryFromKeys = semesterHistoryFromKeys;
            _currentSemester = currentSemester;
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
      // Query students with multiple possible field combinations
      final queries = [
        FirebaseFirestore.instance
            .collection("colleges")
            .doc("students")
            .collection("all_students")
            .where("class", isEqualTo: widget.className)
            .where("departmentId", isEqualTo: widget.departmentId),

        FirebaseFirestore.instance
            .collection("colleges")
            .doc("students")
            .collection("all_students")
            .where("className", isEqualTo: widget.className)
            .where("departmentId", isEqualTo: widget.departmentId),

        FirebaseFirestore.instance
            .collection("colleges")
            .doc("students")
            .collection("all_students")
            .where("class", isEqualTo: widget.className.toLowerCase())
            .where("departmentId", isEqualTo: widget.departmentId),
      ];

      Set<String> processedStudentIds = {};
      int totalUpdatedStudents = 0;

      for (final query in queries) {
        try {
          final studentsSnapshot = await query.get();
          final batch = FirebaseFirestore.instance.batch();
          int batchCount = 0;

          for (var studentDoc in studentsSnapshot.docs) {
            if (processedStudentIds.contains(studentDoc.id)) continue;
            processedStudentIds.add(studentDoc.id);

            batch.update(studentDoc.reference, {
              'currentSemester': semester,
              'semesterStartDate': semesterData['startDate'],
              'semesterEndDate': semesterData['endDate'],
              'semesterUpdatedAt': FieldValue.serverTimestamp(),
            });
            batchCount++;

            // Commit in batches of 500 (Firestore limit)
            if (batchCount >= 500) {
              await batch.commit();
              totalUpdatedStudents += batchCount;
              batchCount = 0;
            }
          }

          if (batchCount > 0) {
            await batch.commit();
            totalUpdatedStudents += batchCount;
          }
        } catch (e) {
          debugPrint("Error in query: $e");
        }
      }

      _showSnackBar("Set semester $semester as current for $totalUpdatedStudents students");
    } catch (e) {
      debugPrint("Error updating students: $e");
      _showSnackBar("Warning: Some students may not have been updated");
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
    if (_selectedSemester == null ||
        _semesterStartDate == null ||
        _semesterEndDate == null) {
      _showSnackBar("Please select semester and time period first");
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("Updating students..."),
            ],
          ),
        ),
      );

      final classDocRef = await getClassDocRef();
      final semesterData = {
        'semester': _selectedSemester,
        'startDate': Timestamp.fromDate(_semesterStartDate!),
        'endDate': Timestamp.fromDate(_semesterEndDate!),
        'createdAt': FieldValue.serverTimestamp(),
      };

      await classDocRef.set({
        'currentSemester': {
          'semester': _selectedSemester,
          'startDate': Timestamp.fromDate(_semesterStartDate!),
          'endDate': Timestamp.fromDate(_semesterEndDate!),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        'semesterHistory.$_selectedSemester': semesterData,
      }, SetOptions(merge: true));

      await _updateStudentsForClass(_selectedSemester!, {
        'startDate': Timestamp.fromDate(_semesterStartDate!),
        'endDate': Timestamp.fromDate(_semesterEndDate!),
      });

      if (Navigator.canPop(context)) Navigator.pop(context);

      setState(() {
        _currentSemester = _selectedSemester;
      });

      await _fetchSemesterHistory();
    } catch (e, st) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      debugPrint("Error updating students: $e\n$st");
      _showSnackBar("Failed to update students: $e");
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

      semesterFaculty.add({
        'facultyId': facultyId,
        'subject': subject,
        'addedAt': FieldValue.serverTimestamp(),
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
            IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _refreshData),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.white),
              onPressed: () {
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
              },
            ),
          ],
        ),
      ),

      body: SafeArea(
        child: Column(
          children: [
            // Semester selector + Add button
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
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
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    ),
                  ),
                ],
              ),
            ),

            // Main content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshData,
                child: ListView(
                  padding: EdgeInsets.zero,
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
                              color: Color(0xFF2D2F38),
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
                        color: const Color(0xFF2D2F38),
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
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
            color: Color(0xFFE5E5E5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          IconButton(
              icon: Image.asset("assets/search.png", height: 26), onPressed: () {}),
          IconButton(
              icon: Image.asset("assets/homeLogo.png", height: 32),
              onPressed: () => Navigator.pop(context)),
          IconButton(
              icon: Image.asset("assets/account.png", height: 26), onPressed: () {}),
        ]),
      ),
    );
  }
}