import 'package:camsvirtusa/Shared/newsScreen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'studentDashboard.dart';
import 'studentProfile.dart';

class TimeTablePage extends StatefulWidget {
  final String studentId;
  const TimeTablePage({Key? key, required this.studentId}) : super(key: key);

  @override
  _TimeTablePageState createState() => _TimeTablePageState();
}

class _TimeTablePageState extends State<TimeTablePage> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentSemester;
  Map<String, dynamic>? _timetableData;
  List<dynamic>? _courseMappings;

  @override
  void initState() {
    super.initState();
    _fetchTimetable();
  }

  Future<void> _fetchTimetable() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // 1) Fetch student document to get department and class
      final studentDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .get();

      if (!studentDoc.exists) {
        throw Exception("Student record not found in database.");
      }

      final studentData = studentDoc.data() as Map<String, dynamic>;
      final String? department = studentData['department'];
      final String? className = studentData['class'];

      if (department == null || className == null) {
        throw Exception("Student department or class not configured.");
      }

      // 2) Fetch class document to get current semester and timetable
      final classDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(department)
          .collection('clasees') // keeping correct spelling from classControl.dart
          .doc(className)
          .get();

      if (classDoc.exists) {
        final classData = classDoc.data() as Map<String, dynamic>;
        final semesterField = classData['currentSemester'];
        if (semesterField is Map) {
          _currentSemester = semesterField['semester']?.toString() ?? 'V';
        } else {
          _currentSemester = semesterField?.toString() ?? 'V';
        }
        final timetables = classData['timetables'] as Map?;
        if (timetables != null && _currentSemester != null) {
          final semTimetable = timetables[_currentSemester];
          if (semTimetable is Map) {
            _timetableData = semTimetable.cast<String, dynamic>();
          }
        }
        final mappings = classData['courseMapping'] as Map?;
        if (mappings != null && _currentSemester != null) {
          _courseMappings = mappings[_currentSemester] as List?;
        }
      } else {
        _currentSemester = 'V'; // fallback default
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF7F50)),
              ),
            )
          : _errorMessage != null
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
              : RefreshIndicator(
                  onRefresh: _fetchTimetable,
                  color: const Color(0xFFFF7F50),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      // Current Semester Section
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(left: 16, right: 16, top: 45, bottom: 16),
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF36454F), // Dark gray
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'CURRENT SEMESTER : ${_currentSemester ?? "V"}',
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
    );
  }

  Widget _buildTimeTableGrid() {
    if (_timetableData == null || _timetableData!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60.0, horizontal: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.calendar_today, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No timetable configured for this semester.',
                style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

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
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }).toList(),
            ),
            // Days rows
            ...days.map((day) {
              final periodsList = _timetableData![day] as List?;
              return TableRow(
                children: [
                  // Day Label cell
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
                    color: const Color(0xFFF9F9F9),
                    alignment: Alignment.center,
                    child: Text(
                      day.toUpperCase().substring(0, 3), // e.g. MON
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
                        ? periodsList[index]?.toString() ?? ""
                        : "";
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 1),
                      alignment: Alignment.center,
                      child: Text(
                        val.isEmpty ? "-" : val,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: val.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                          color: val.isNotEmpty ? const Color(0xFFFF7F50) : Colors.grey,
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
    if (_courseMappings == null || _courseMappings!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E5E5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'COURSE DETAILS & HANDLING FACULTY',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const Divider(height: 24, thickness: 1.5),
            ..._courseMappings!.map((mapping) {
              final mapData = mapping as Map<String, dynamic>?;
              if (mapData == null) return const SizedBox.shrink();

              final abbrev = mapData['abbreviation'] ?? '';
              final name = mapData['name'] ?? '';
              final facultyName = mapData['facultyName'] ?? '';
              final isElective = mapData['isElective'] ?? false;
              final name2 = mapData['name2'] ?? '';
              final facultyName2 = mapData['facultyName2'] ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7F50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        abbrev,
                        style: const TextStyle(
                          color: Color(0xFFFF7F50),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Staff: $facultyName',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (isElective) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "OR",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              name2,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF334155),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Staff: $facultyName2',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _goToDashboard(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDashboard(studentId: widget.studentId),
      ),
    );
  }

}
