import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
            style: TextStyle(color: Colors.white, fontSize: 20)
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
        separatorBuilder: (_, __) =>
        const SizedBox(height: 12),
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
              trailing: const Icon(Icons.arrow_forward_ios,
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

  Future<String?> getAttendanceStatus({
    required String studentId,
    required DateTime date,
    required String hour, // "1" for 1st hour, "2" for 2nd, etc.
    required String subject,
  }) async {
    final dateKey = DateFormat('dd-MM-yyyy').format(date);
    final hourIdx = (int.tryParse(hour) ?? 1) - 1; // 0-based indexing

    final docRef = FirebaseFirestore.instance
        .collection('colleges')
        .doc('students')
        .collection('all_students')
        .doc(studentId);

    final docSnap = await docRef.get();
    if (!docSnap.exists) return null;

    final data = docSnap.data();
    if (data == null || data[dateKey] == null) return null;

    final dailyAttendance = Map<String, dynamic>.from(data[dateKey]);
    final hourEntry = dailyAttendance["$hourIdx"];
    if (hourEntry == null) return null;

    // hourEntry is like: { "JAVA PROGRAMMING": "A" }
    if (hourEntry is Map) {
      if (hourEntry.containsKey(subject)) {
        return hourEntry[subject]; // "P" or "A"
      }
    }
    return null;
  }
  @override
  State<ClassAttendanceScreen> createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen> {
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

  Future<void> _initData() async {
    try {
      // Set default values immediately to reduce initial delay
      selectedSemester = semesters.first;
      selectedHour = hours.first;

      // Load students and semester data in parallel
      await Future.wait([
        _fetchStudentsForClass(),
        _loadSemesterData(selectedSemester!),
      ]);

      // Load existing attendance after data is ready
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
    setState(() => subjectsLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(widget.departmentId)
          .collection('classes')
          .doc(widget.className)
          .get();

      if (doc.exists) {
        final data = doc.data() ?? {};
        subjects = List<String>.from(data[semester] ?? []);
      } else {
        subjects = [];
      }
    } catch (e) {
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

      final data = doc.data() ?? {};
      facultySubjectMappings = List<Map<String, dynamic>>.from(
        (data['faculty']?[semester] ?? []),
      );
    } catch (e) {
      setState(() {
        error = 'Error fetching faculty-subject mapping: $e';
      });
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
    } catch (e) {
      setState(() {
        error = 'Error fetching students: $e';
      });
    }
  }

  // Optimized method to fetch existing attendance data using batch queries
  Future<void> _loadExistingAttendance() async {
    if (selectedSubject == null || selectedHour == null || students.isEmpty) return;

    setState(() => isLoadingAttendance = true);

    try {
      final dateKey = DateFormat('dd-MM-yyyy').format(selectedDate);

      // Get hour range for continuous mode
      List<int> hourIndices = [];
      if (isContinuousMode && selectedEndHour != null) {
        final startHour = int.tryParse(selectedHour!) ?? 1;
        final endHour = int.tryParse(selectedEndHour!) ?? 1;
        final start = startHour <= endHour ? startHour : endHour;
        final end = startHour <= endHour ? endHour : startHour;
        for (int i = start; i <= end; i++) {
          hourIndices.add(i - 1); // Convert to 0-based indexing
        }
      } else {
        hourIndices = [(int.tryParse(selectedHour!) ?? 1) - 1];
      }

      // Reset attendance to false first
      attendance = {for (var s in students) s['id']: false};

      // Split students into batches of 10 for parallel processing
      const batchSize = 10;
      final batches = <List<Map<String, dynamic>>>[];

      for (int i = 0; i < students.length; i += batchSize) {
        final end = (i + batchSize < students.length) ? i + batchSize : students.length;
        batches.add(students.sublist(i, end));
      }

      // Process batches in parallel with timeout
      final futures = batches.map((batch) => _loadAttendanceForBatch(batch, dateKey, hourIndices));
      await Future.wait(futures).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Attendance loading timed out');
          return <void>[];
        },
      );

    } catch (e) {
      print('Error loading existing attendance: $e');
    } finally {
      setState(() => isLoadingAttendance = false);
    }
  }

  // Helper method to load attendance for a batch of students
  Future<void> _loadAttendanceForBatch(
      List<Map<String, dynamic>> batch,
      String dateKey,
      List<int> hourIndices
      ) async {
    // Create futures for parallel execution within the batch
    final futures = batch.map((student) async {
      final studentId = student['id'];

      try {
        final docRef = FirebaseFirestore.instance
            .collection('colleges')
            .doc('students')
            .collection('all_students')
            .doc(studentId);

        final docSnap = await docRef.get();
        if (!docSnap.exists) return;

        final data = docSnap.data();
        if (data == null || data[dateKey] == null) return;

        final dailyAttendance = Map<String, dynamic>.from(data[dateKey]);

        // Check if student is present in ALL selected hours
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

  // Optimized method to reload attendance when date, hour, or subject changes
  void _onSelectionChanged() {
    if (selectedSubject != null && selectedHour != null && students.isNotEmpty) {
      // Validate continuous mode selection
      if (isContinuousMode && selectedEndHour != null) {
        final startHour = int.tryParse(selectedHour!) ?? 1;
        final endHour = int.tryParse(selectedEndHour!) ?? 1;
        if (endHour < startHour) {
          // Auto-correct if end hour is before start hour
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

  Future<void> _saveAttendance() async {
    if (students.isEmpty ||
        selectedSubject == null ||
        selectedSemester == null ||
        selectedHour == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select semester, subject, hour and have students')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final dateKey = DateFormat('dd-MM-yyyy').format(selectedDate);
      final subject = selectedSubject!;

      // Get hour range for continuous mode
      List<int> hourIndices = [];
      if (isContinuousMode && selectedEndHour != null) {
        final startHour = int.tryParse(selectedHour!) ?? 1;
        final endHour = int.tryParse(selectedEndHour!) ?? 1;
        final start = startHour <= endHour ? startHour : endHour;
        final end = startHour <= endHour ? endHour : startHour;
        for (int i = start; i <= end; i++) {
          hourIndices.add(i - 1); // Convert to 0-based indexing
        }
      } else {
        hourIndices = [(int.tryParse(selectedHour!) ?? 1) - 1];
      }

      // Process in batches to improve performance
      const batchSize = 10;
      final batches = <List<Map<String, dynamic>>>[];

      for (int i = 0; i < students.length; i += batchSize) {
        final end = (i + batchSize < students.length) ? i + batchSize : students.length;
        batches.add(students.sublist(i, end));
      }

      // Process all batches in parallel
      final futures = batches.map((batch) => _saveAttendanceForBatch(batch, dateKey, hourIndices, subject));
      await Future.wait(futures);

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

  // Helper method to save attendance for a batch of students
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
        final docRef = FirebaseFirestore.instance
            .collection('colleges')
            .doc('students')
            .collection('all_students')
            .doc(studentId);

        // Get the existing doc to avoid overwriting previous hours
        final docSnap = await docRef.get();
        final data = docSnap.data() ?? {};

        Map<String, dynamic> attendanceDay = {};
        if (data[dateKey] != null) {
          // Already has attendance for this date, keep existing structure
          attendanceDay = Map<String, dynamic>.from(data[dateKey]);
        }

        // Update attendance for all selected hours
        for (final hourIdx in hourIndices) {
          attendanceDay["$hourIdx"] = {subject: status};
        }

        // Update the dateKey field with the new attendanceDay map
        await docRef.set({dateKey: attendanceDay}, SetOptions(merge: true));
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
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(kPrimary),
                strokeWidth: 3,
              ),
              SizedBox(height: 24),
              Text(
                'Loading class data...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black54,
                ),
              ),
              SizedBox(height: 8),
              Text(
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
        .where((s) =>
    s['name'].toLowerCase().contains(searchQuery.toLowerCase()) ||
        s['id'].toLowerCase().contains(searchQuery.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kPrimary,
        elevation: 0,
        title: const Text(
          'MARK ATTENDANCE',
          style: TextStyle(color: Colors.white, fontSize: 24),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: isSaving ? null : _saveAttendance,
          ),
        ],
        leading: const BackButton(color: Colors.white),
      ),
      body: Column(
        children: [
          // Top Dropdowns: Semester and Subject
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSemester,
                        isExpanded: true,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('Select Sem'),
                        ),
                        onChanged: (v) async {
                          if (v != null) {
                            setState(() => selectedSemester = v);
                            await _loadSemesterData(v);
                            _onSelectionChanged(); // Load attendance for new semester
                          }
                        },
                        items: semesters
                            .map((e) =>
                            DropdownMenuItem(
                              value: e,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(e),
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
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedSubject,
                        isExpanded: true,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text('Select Subject'),
                        ),
                        onChanged: (v) {
                          setState(() => selectedSubject = v);
                          _onSelectionChanged(); // Load attendance for new subject
                        },
                        items: getSubjectsForThisFaculty()
                            .map((e) =>
                            DropdownMenuItem(
                              value: e,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(e),
                              ),
                            ))
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Calendar Row (date picker)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: SizedBox(
              height: 62,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: getDateList().map((date) {
                  final isSelected = DateFormat('yyyy-MM-dd').format(date) ==
                      DateFormat('yyyy-MM-dd').format(selectedDate);
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => selectedDate = date);
                        _onSelectionChanged(); // Load attendance for new date
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected ? kPrimary : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                                color: kShadow,
                                blurRadius: 6,
                                offset: Offset(1, 4))
                          ],
                        ),
                        width: 62,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('dd').format(date),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                            Text(
                              DateFormat('EEE').format(date),
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.black54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Search & Hour Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Column(
              children: [
                // Search and Continuous Mode Toggle
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: kShadow,
                              blurRadius: 3,
                              offset: Offset(1, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          decoration: const InputDecoration(
                            hintText: "Search students",
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.search),
                            contentPadding:
                            EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          onChanged: (val) =>
                              setState(() => searchQuery = val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: isContinuousMode ? kPrimary : Colors.grey[300],
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
                              style: TextStyle(
                                color: isContinuousMode ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Hour Selection Row
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
                            hint: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8.0),
                              child: Text(
                                'Start Hour',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                            onChanged: (v) {
                              setState(() {
                                selectedHour = v;
                                // Reset end hour if it's before start hour
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
                            items: hours
                                .map((e) =>
                                DropdownMenuItem(
                                  value: e,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      isContinuousMode ? 'Hour $e' : 'Hour $e',
                                      style:
                                      const TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ))
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                    if (isContinuousMode) ...[
                      const SizedBox(width: 8),
                      const Text(
                        'to',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black54,
                        ),
                      ),
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
                              hint: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(
                                  'End Hour',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              onChanged: (v) {
                                setState(() => selectedEndHour = v);
                                _onSelectionChanged();
                              },
                              style: const TextStyle(color: Colors.white),
                              iconEnabledColor: Colors.white,
                              items: getAvailableEndHours()
                                  .map((e) =>
                                  DropdownMenuItem(
                                    value: e,
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Text(
                                        'Hour $e',
                                        style:
                                        const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ))
                                  .toList(),
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
            padding: const EdgeInsets.only(top: 10, left: 0, right: 0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF222F3E),
                //color: kBackground,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 0),
                child: Row(
                  children: [
                    const Expanded(
                      flex: 2,
                      child: Text("STUDENT ID",
                        style:
                        const TextStyle(color: Colors.white)),
                    ),
                    const Expanded(
                      flex: 3,
                      child: Text("NAME",
                        style:
                        const TextStyle(color: Colors.white)),
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
                            style:
                            const TextStyle(color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert, size: 18,color:Colors.white),
                            onSelected: (value) {
                              if (value == 'all_present') {
                                _markAll(true);
                              } else if (value == 'all_absent') {
                                _markAll(false);
                              }
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
          // Student List
          Expanded(
            child: Stack(
              children: [
                filteredStudents.isEmpty
                    ? const Center(child: Text("No students found."))
                    : ListView.separated(
                  itemCount: filteredStudents.length,
                  separatorBuilder: (_, __) =>
                      Divider(
                        color: kPrimary,
                        height: 1,
                        thickness: 0.7,
                      ),
                  itemBuilder: (context, i) {
                    final s = filteredStudents[i];
                    final sid = s['id'];
                    final sname = s['name'];
                    final present = attendance[sid] ?? false;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                sid,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              sname,
                              style: const TextStyle(
                                fontWeight: FontWeight.w400,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Switch(
                                value: present,
                                activeColor: Colors.green,
                                inactiveThumbColor: Colors.red,
                                onChanged: (v) =>
                                    setState(() {
                                      attendance[sid] = v;
                                    }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // Loading overlay for attendance fetching
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
          // Bottom Navigation

        ],
      ),
    );
  }
}