import 'package:camsvirtusa/Shared/newsScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'facultyDashboard.dart';
import 'facultyProfile.dart';

class TimeTablePage extends StatefulWidget {
  final String facultyId;
  const TimeTablePage({Key? key, required this.facultyId}) : super(key: key);

  @override
  _TimeTablePageState createState() => _TimeTablePageState();
}

class _TimeTablePageState extends State<TimeTablePage> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _department;
  List<String> _assignedClasses = [];
  Map<String, List<String>> _teacherSchedule = {
    "Monday": List.filled(7, ""),
    "Tuesday": List.filled(7, ""),
    "Wednesday": List.filled(7, ""),
    "Thursday": List.filled(7, ""),
    "Friday": List.filled(7, ""),
  };

  @override
  void initState() {
    super.initState();
    _fetchFacultyData();
  }

  Future<void> _fetchFacultyData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 1) Fetch faculty document to get department and classes
      final docRef = FirebaseFirestore.instance
          .collection('colleges')
          .doc('faculties')
          .collection('all_faculties')
          .doc(widget.facultyId);

      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        throw Exception("Faculty record not found in database.");
      }

      final data = docSnap.data() as Map<String, dynamic>;
      _department = data['department'];
      final classesData = data['classes'] as List?;
      if (classesData != null) {
        _assignedClasses = classesData.map((c) => c.toString()).toList();
      }

      if (_assignedClasses.isNotEmpty) {
        await _fetchTimetable();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTimetable() async {
    if (_department == null || _assignedClasses.isEmpty) return;

    try {
      setState(() {
        _isLoading = true;
        _teacherSchedule = {
          "Monday": List.filled(7, ""),
          "Tuesday": List.filled(7, ""),
          "Wednesday": List.filled(7, ""),
          "Thursday": List.filled(7, ""),
          "Friday": List.filled(7, ""),
        };
      });

      for (var className in _assignedClasses) {
        final classDoc = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('departments')
            .collection('all_departments')
            .doc(_department)
            .collection('clasees')
            .doc(className)
            .get();

        if (classDoc.exists) {
          final classData = classDoc.data() as Map<String, dynamic>;
          final semesterField = classData['currentSemester'];
          String sem = 'V';
          if (semesterField is Map) {
            sem = semesterField['semester']?.toString() ?? 'V';
          } else {
            sem = semesterField?.toString() ?? 'V';
          }

          final timetables = classData['timetables'] as Map?;
          final mappings = classData['courseMapping'] as Map?;

          if (timetables != null && mappings != null) {
            final semTimetable = timetables[sem] as Map?;
            final semMappings = mappings[sem] as List?;

            if (semTimetable != null && semMappings != null) {
              final days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
              for (var day in days) {
                final periodsList = semTimetable[day] as List?;
                if (periodsList != null) {
                  for (int i = 0; i < 7; i++) {
                    if (i < periodsList.length) {
                      final String abbrev = periodsList[i]?.toString() ?? "";
                      if (abbrev.isNotEmpty && abbrev != "-") {
                        final mapping = semMappings.firstWhere((m) {
                          final mapData = m as Map?;
                          if (mapData == null) return false;
                          if (mapData['abbreviation']?.toString().toLowerCase() != abbrev.toLowerCase()) return false;
                          
                          final isPrimaryFaculty = mapData['facultyId']?.toString().toUpperCase() == widget.facultyId.toUpperCase();
                          final isSecondaryFaculty = mapData['isElective'] == true && 
                                                     mapData['facultyId2']?.toString().toUpperCase() == widget.facultyId.toUpperCase();
                          
                          return isPrimaryFaculty || isSecondaryFaculty;
                        }, orElse: () => null);

                        if (mapping != null) {
                          _teacherSchedule[day]![i] = "$className\n($abbrev)";
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar( // Orange color
        title: const Text(
          'TIME TABLE',
          style: const TextStyle(
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
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7F50)),
                          ),
                        )
                      : _assignedClasses.isEmpty
                          ? const Center(
                              child: Text(
                                'No classes assigned to you.',
                                style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _fetchTimetable,
                              color: const Color(0xFFFF7F50),
                              child: ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  // Header Section
                                  Center(
                                    child: Container(
                                      margin: const EdgeInsets.only(top: 24, bottom: 16),
                                      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF36454F), // Dark gray
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'TEACHER WEEKLY SCHEDULE',
                                        style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
                                      ),
                                    ),
                                  ),

                                  // Time Table Scrollable Grid
                                  _buildTimeTableGrid(),

                                  // Course details and faculty mappings
                                  _buildCourseMappingsList(),

                                  const SizedBox(height: 100),
                                ],
                              ),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildTimeTableGrid() {
    final days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"];
    final headers = [
      "Day", 
      "P1\n9:00 - 9:50", 
      "P2\n9:50 - 10:40", 
      "P3\n10:55 - 11:45", 
      "P4\n11:45 - 12:35", 
      "P5\n1:25 - 2:15", 
      "P6\n2:15 - 3:05", 
      "P7\n3:20 - 4:10"
    ];

    return SizedBox(
      height: 380,
      child: InteractiveViewer(
        boundaryMargin: const EdgeInsets.all(50.0),
        minScale: 0.8,
        maxScale: 4.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Table(
            defaultColumnWidth: const FlexColumnWidth(),
            border: TableBorder.all(
              color: const Color(0xFF36454F),
              width: 1.0,
              borderRadius: BorderRadius.circular(6),
            ),
            children: [
              // Headers row
              TableRow(
                decoration: const BoxDecoration(color: Color(0xFFE5E5E5)),
                children: headers.map((header) {
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                    alignment: Alignment.center,
                    child: Text(
                      header,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }).toList(),
              ),
              // Days rows
              ...days.map((day) {
                final periodsList = _teacherSchedule[day];
                return TableRow(
                  children: [
                    // Day Label cell
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                      color: const Color(0xFFF9F9F9),
                      alignment: Alignment.center,
                      child: Text(
                        day.toUpperCase().substring(0, 3),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFF7F50),
                        ),
                      ),
                    ),
                    // 7 periods cells
                    ...List.generate(7, (index) {
                      final String val = (periodsList != null && index < periodsList.length)
                          ? periodsList[index]
                          : "";
                      final bool hasClass = val.isNotEmpty;
                      return Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 1),
                        color: hasClass ? const Color(0xFFFF7F50).withOpacity(0.15) : null,
                        alignment: Alignment.center,
                        child: Text(
                          hasClass ? val : "-",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: hasClass ? FontWeight.bold : FontWeight.normal,
                            color: hasClass ? const Color(0xFFFF7F50) : Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseMappingsList() {
    return const SizedBox.shrink();
  }

  void _goToDashboard(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FacultyDashboard(facultyId: widget.facultyId),
      ),
    );
  }

}
