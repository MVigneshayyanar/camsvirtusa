import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class TodayScheduleWidget extends StatefulWidget {
  final String userType; // 'student' or 'faculty'
  final String userId;

  const TodayScheduleWidget({
    Key? key,
    required this.userType,
    required this.userId,
  }) : super(key: key);

  @override
  State<TodayScheduleWidget> createState() => _TodayScheduleWidgetState();
}

class _TodayScheduleWidgetState extends State<TodayScheduleWidget> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _todaySchedule = [];
  int _currentPeriodIndex = -1;

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
  final timeLabels = [
    "9:00 - 9:50",
    "9:50 - 10:40",
    "10:55 - 11:45",
    "11:45 - 12:35",
    "1:25 - 2:15",
    "2:15 - 3:05",
    "3:20 - 4:10"
  ];

  @override
  void initState() {
    super.initState();
    _fetchSchedule();
  }

  void _calculateCurrentPeriod() {
    final now = DateTime.now();
    int currentIdx = -1;
    for (int i = 0; i < 7; i++) {
      final start = DateTime(now.year, now.month, now.day, periodStartTimes[i]['hour']!, periodStartTimes[i]['minute']!);
      final end = DateTime(now.year, now.month, now.day, periodEndTimes[i]['hour']!, periodEndTimes[i]['minute']!);
      if (now.isAfter(start) && now.isBefore(end)) {
        currentIdx = i;
        break;
      }
    }
    setState(() {
      _currentPeriodIndex = currentIdx;
    });
  }

  Future<void> _fetchSchedule() async {
    try {
      _calculateCurrentPeriod();
      final now = DateTime.now();
      final daysOfWeek = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"];
      final String today = daysOfWeek[now.weekday - 1];

      if (today == "Saturday" || today == "Sunday") {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      List<Map<String, dynamic>> schedule = List.filled(7, {});

      if (widget.userType == 'student') {
        final doc = await FirebaseFirestore.instance.collection('colleges').doc('students').collection('all_students').doc(widget.userId).get();
        if (doc.exists) {
          final data = doc.data()!;
          final dept = data['department'];
          final className = data['class'];
          if (dept != null && className != null) {
            final classDoc = await FirebaseFirestore.instance.collection('colleges').doc('departments').collection('all_departments').doc(dept).collection('clasees').doc(className).get();
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
                  for (int i = 0; i < 7 && i < todayPeriods.length; i++) {
                    if (todayPeriods[i] != null && todayPeriods[i].toString().isNotEmpty) {
                      schedule[i] = {
                        'subject': todayPeriods[i].toString(),
                        'period': i,
                      };
                    }
                  }
                }
              }
            }
          }
        }
      } else if (widget.userType == 'faculty') {
        final doc = await FirebaseFirestore.instance.collection('colleges').doc('faculties').collection('all_faculties').doc(widget.userId).get();
        if (doc.exists) {
          final data = doc.data()!;
          final dept = data['department'];
          final assignedClasses = data['classes'] as List?;
          if (dept != null && assignedClasses != null) {
            for (var className in assignedClasses) {
              final classDoc = await FirebaseFirestore.instance.collection('colleges').doc('departments').collection('all_departments').doc(dept).collection('clasees').doc(className.toString()).get();
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
                    for (int i = 0; i < 7 && i < todayPeriods.length; i++) {
                      var subjectStr = todayPeriods[i]?.toString() ?? "";
                      if (subjectStr.contains("(") && subjectStr.contains(")")) {
                        var parts = subjectStr.split("(");
                        var sub = parts[0].trim();
                        var facStr = parts[1].replaceAll(")", "").trim();
                        var facs = facStr.split(",");
                        if (facs.any((f) => f.trim() == widget.userId || f.trim() == data['abbreviation'])) {
                          schedule[i] = {
                            'subject': "$sub - $className",
                            'period': i,
                          };
                        }
                      } else if (subjectStr.isNotEmpty && subjectStr.contains(widget.userId) || subjectStr.contains(data['abbreviation'] ?? '')) {
                         schedule[i] = {
                            'subject': "$subjectStr - $className",
                            'period': i,
                          };
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _todaySchedule = schedule;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: Color(0xFFFF7F50)),
      );
    }
    
    if (_errorMessage.isNotEmpty) {
      return Container(
        height: 100,
        alignment: Alignment.center,
        child: Text("Error: $_errorMessage", style: const TextStyle(color: Colors.red)),
      );
    }

    bool hasClasses = _todaySchedule.any((period) => period.isNotEmpty);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF36454F),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF7F50).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.calendar_month,
                  color: Color(0xFFFF7F50),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                "TODAY's SCHEDULE",
                style: TextStyle(
                  color: Color(0xFFFF7F50),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasClasses)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                "No classes today.",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(7, (index) {
                  var period = _todaySchedule[index];
                  bool isCurrent = _currentPeriodIndex == index;
                  bool hasClass = period.isNotEmpty;

                  // Find the first upcoming or current index if not strictly in a period
                  int firstUpcomingIdx = _currentPeriodIndex;
                  if (firstUpcomingIdx == -1) {
                    firstUpcomingIdx = 7;
                    final now = DateTime.now();
                    for (int i = 0; i < 7; i++) {
                      final end = DateTime(now.year, now.month, now.day, periodEndTimes[i]['hour']!, periodEndTimes[i]['minute']!);
                      if (now.isBefore(end)) {
                        firstUpcomingIdx = i;
                        break;
                      }
                    }
                  }

                  // Hide completed hours (in the past)
                  if (index < firstUpcomingIdx) return const SizedBox.shrink();
                  // Hide future empty hours
                  if (!hasClass && !isCurrent && index > firstUpcomingIdx) return const SizedBox.shrink();

                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCurrent ? Colors.green.shade500 : (hasClass ? Colors.white.withOpacity(0.1) : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                      border: isCurrent ? null : Border.all(color: hasClass ? Colors.white24 : Colors.white10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          timeLabels[index],
                          style: TextStyle(
                            color: isCurrent ? Colors.white : Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          hasClass ? (period['subject'] ?? '') : 'Free',
                          style: TextStyle(
                            color: isCurrent ? Colors.white : (hasClass ? Colors.white : Colors.white54),
                            fontSize: 12,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}
