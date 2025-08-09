import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MarkAttendance extends StatefulWidget {
  final String facultyId;

  const MarkAttendance({Key? key, required this.facultyId}) : super(key: key);

  @override
  _MarkAttendanceState createState() => _MarkAttendanceState();
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

      if (!doc.exists) {
        setState(() {
          error = 'Faculty not found';
          isLoading = false;
        });
        return;
      }

      final data = doc.data();
      facultyName = data?['name'] ?? 'Unknown Faculty';
      departmentId = data?['department'] ?? '';

      if (data != null && data['classes'] != null) {
        classes = List<String>.from(data['classes']);
      } else {
        classes = [];
      }
      error = '';
    } catch (e) {
      error = 'Error loading classes: $e';
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
      appBar: AppBar(
        title: Text(facultyName.isNotEmpty
            ? 'Mark Attendance - $facultyName'
            : 'Mark Attendance'),
        backgroundColor: Colors.deepOrangeAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : (error.isNotEmpty
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
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(className,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () => _openClassAttendance(className),
            ),
          );
        },
      )),
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
  _ClassAttendanceScreenState createState() => _ClassAttendanceScreenState();
}

class _ClassAttendanceScreenState extends State<ClassAttendanceScreen> {
  bool isLoading = true;
  bool subjectsLoading = false;
  String error = '';

  List<Map<String, dynamic>> students = [];
  Map<String, bool> attendance = {};

  List<String> subjects = [];
  String? selectedSubject;

  final List<String> semesters = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'];
  String? selectedSemester;

  // Faculty-subject mapping for this class and semester
  List<Map<String, dynamic>> facultySubjectMappings = [];

  @override
  void initState() {
    super.initState();
    _fetchClassData();
  }

  Future<void> _fetchClassData() async {
    await _fetchStudentsForClass();
    setState(() {
      selectedSemester = semesters.first;
    });
    await _fetchSubjectsForSemester(selectedSemester!);
    await _fetchFacultySubjectMapping(selectedSemester!);
    setState(() {
      isLoading = false;
    });

    _printFacultyIdAndSubject(selectedSemester!);
  }

  Future<void> _fetchSubjectsForSemester(String semester) async {
    setState(() {
      subjectsLoading = true;
      selectedSubject = null; // reset when semester changes
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(widget.departmentId)
          .collection('classes')
          .doc(widget.className)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        if (data.containsKey(semester) && data[semester] is List) {
          subjects = List<String>.from(data[semester]);
          selectedSubject = subjects.isNotEmpty ? subjects.first : null;
        } else {
          subjects = [];
          selectedSubject = null;
        }
      }
    } catch (e) {
      error = 'Error loading subjects: $e';
    } finally {
      setState(() {
        subjectsLoading = false;
      });
    }
  }

  Future<void> _fetchFacultySubjectMapping(String semester) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(widget.departmentId)
          .collection('classes')
          .doc(widget.className)
          .get();
      print(doc);

      if (!doc.exists || doc.data() == null) {
        facultySubjectMappings = [];
        return;
      }

      final data = doc.data()!;
      final facultyMap = data['faculty'];
      if (facultyMap == null || facultyMap[semester] == null) {
        facultySubjectMappings = [];
        return;
      }

      facultySubjectMappings = List<Map<String, dynamic>>.from(facultyMap[semester]);
    } catch (e) {
      print('Error fetching faculty-subject mapping: $e');
      facultySubjectMappings = [];
    }
  }

  // Print each facultyId and subject for the current selectedSemester
  void _printFacultyIdAndSubject(String semester) {
    for (final mapping in facultySubjectMappings) {
      final facultyId = mapping['facultyId'];
      final subject = mapping['subject'];
      if (facultyId != null && subject != null) {
        print('Faculty ID: $facultyId, Subject: $subject');
      }
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

      final fetchedStudents = query.docs.map((d) {
        final data = d.data();
        final id = d.id;
        final name = (data['name'] ?? 'Unknown').toString();
        return {'id': id, 'name': name, ...data};
      }).toList();

      students = fetchedStudents;
      attendance = {for (var s in students) s['id'].toString(): false};
    } catch (e) {
      error = 'Error fetching students: $e';
    }
  }

  Future<void> _saveAttendance() async {
    if (students.isEmpty || selectedSubject == null || selectedSemester == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select semester, subject and have students')),
      );
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();

      for (final s in students) {
        final studentId = s['id'].toString();
        final isPresent = attendance[studentId] ?? false;

        final docRef = FirebaseFirestore.instance
            .collection('colleges')
            .doc('departments')
            .collection('all_departments')
            .doc(widget.departmentId)
            .collection('classes')
            .doc(widget.className)
            .collection('attendance')
            .doc(selectedSemester!)
            .collection(selectedSubject!)
            .doc(studentId);

        batch.set(docRef, {
          'present': isPresent,
          'timestamp': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  List<String> getSubjectsForThisFaculty() {
    final facultyId = widget.facultyId;
    return facultySubjectMappings
        .where((m) => m['facultyId'] == facultyId)
        .map((m) => m['subject'] as String)
        .toList();
  }

  // Show subject count popup
  void _showSubjectCountDialog(int count) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subject Count'),
        content: Text('There are $count subjects for the selected semester.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance — ${widget.className}'),
        backgroundColor: Colors.deepOrangeAccent,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error.isNotEmpty
          ? Center(child: Text(error))
          : students.isEmpty
          ? const Center(child: Text('No students found for this class'))
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedSemester,
                    decoration: const InputDecoration(
                      labelText: "Select Semester",
                      border: OutlineInputBorder(),
                    ),
                    items: semesters
                        .map((sem) => DropdownMenuItem(
                      value: sem,
                      child: Text(sem),
                    ))
                        .toList(),
                    onChanged: (value) async {
                      if (value != null) {
                        setState(() {
                          selectedSemester = value;
                        });
                        await _fetchSubjectsForSemester(value);
                        await _fetchFacultySubjectMapping(value);
                        setState(() {
                          selectedSubject = null;
                        });
                        _printFacultyIdAndSubject(value);

                        // Show subject count popup
                        int subjectCount = facultySubjectMappings.length;
                        _showSubjectCountDialog(subjectCount);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: subjectsLoading
                      ? Container(
                    height: 60,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  )
                      : DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedSubject,
                    decoration: const InputDecoration(
                      labelText: "Select Subject",
                      border: OutlineInputBorder(),
                    ),
                    items: getSubjectsForThisFaculty()
                        .map((sub) => DropdownMenuItem(
                      value: sub,
                      child: Text(sub),
                    ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedSubject = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // --- Display facultyId and subject on the screen ---
          if (facultySubjectMappings.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Faculty & Subject for Semester",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ...facultySubjectMappings.map((mapping) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                    child: Text(
                      'Faculty ID: ${mapping['facultyId']} | Subject: ${mapping['subject']}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  )),
                ],
              ),
            ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: students.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final s = students[i];
                final sid = s['id'].toString();
                final sname = s['name']?.toString() ?? sid;
                final present = attendance[sid] ?? false;

                return ListTile(
                  leading: const CircleAvatar(
                    backgroundImage: AssetImage(
                      'assets/images/158a1f26-5b1e-4436-a68d-e75b9d98649b.png',
                    ),
                    backgroundColor: Colors.transparent,
                  ),
                  title: Text(sname),
                  subtitle: Text('ID: $sid'),
                  trailing: Checkbox(
                    value: present,
                    onChanged: (v) {
                      setState(() {
                        attendance[sid] = v ?? false;
                      });
                    },
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Attendance'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrangeAccent),
                    onPressed: _saveAttendance,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}