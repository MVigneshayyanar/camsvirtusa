import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// Custom Color Palette
const Color kPrimary = Color(0xFFFF7043);
const Color kBackground = Color(0xFFF9F9F9);
const Color kShadow = Color(0x22000000);

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
          facultyName.isNotEmpty
              ? 'Attendance Register ($facultyName)'
              : 'Attendance Register',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_alt_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {},
        ),
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
              leading: const Icon(Icons.class_, color: kPrimary),
              title: Text(
                className,
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: kPrimary),
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
  final List<String> hours = ['1', '2', '3', '4', '5', '6', '7', '8'];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      await _fetchStudentsForClass();
      selectedSemester = semesters.first;
      await _loadSemesterData(selectedSemester!);
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

  List<String> getSubjectsForThisFaculty() {
    return facultySubjectMappings
        .where((m) => m['facultyId'] == widget.facultyId)
        .map((m) => m['subject'] as String)
        .toList();
  }

  // ... all your imports and previous code ...

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

      // For each student, update their doc in colleges/students/all_students/{studentId}
      // Under a field with dateKey, set an array for each hour
      for (final s in students) {
        final studentId = s['id'];
        final isPresent = attendance[studentId] ?? false;
        final status = isPresent ? "P" : "A";
        final subject = selectedSubject!;

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

        // Prepare the value for this hour (0-indexed)
        // Each hour is a map where key=subject, value=status
        int hourIdx = int.tryParse(selectedHour!) != null ? int.parse(selectedHour!) - 1 : 0;
        attendanceDay["$hourIdx"] = {subject: status};

        // Update the dateKey field with the new attendanceDay map
        await docRef.set({dateKey: attendanceDay}, SetOptions(merge: true));
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    } finally {
      setState(() => isSaving = false);
    }
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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
          'ATTENDENCE REGISTER',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
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
                      onTap: () => setState(() => selectedDate = date),
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
          // Search & Hour
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
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
                        hintText: "Search",
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
                  flex: 1,
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
                            'Hour',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                        onChanged: (v) => setState(() => selectedHour = v),
                        style: const TextStyle(color: Colors.white),
                        iconEnabledColor: Colors.white,
                        items: hours
                            .map((e) =>
                            DropdownMenuItem(
                              value: e,
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  e,
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
                  children: const [
                    Expanded(
                      flex: 2,
                      child: Text("STUDENT ID",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text("NAME",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text("MARK ATTENDANCE",
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Student List
          Expanded(
            child: filteredStudents.isEmpty
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
          ),
          // Bottom Navigation
          Container(
            height: 62,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [BoxShadow(color: kShadow, blurRadius: 6)],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Image.asset(
                    'assets/images/158a1f26-5b1e-4436-a68d-e75b9d98649b.png',
                    width: 34,
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.home, size: 34, color: kPrimary),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(Icons.person, size: 34, color: kPrimary),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}