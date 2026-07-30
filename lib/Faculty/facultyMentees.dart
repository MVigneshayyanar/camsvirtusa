import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'dart:math';
import 'package:intl/intl.dart';

class FacultyMenteesPage extends StatefulWidget {
  final String facultyId;
  const FacultyMenteesPage({Key? key, required this.facultyId}) : super(key: key);

  @override
  State<FacultyMenteesPage> createState() => _FacultyMenteesPageState();
}

class _FacultyMenteesPageState extends State<FacultyMenteesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'MY MENTEES',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: MenteesListTab(facultyId: widget.facultyId),
    );
  }
}

class FacultyODRequestsPage extends StatefulWidget {
  final String facultyId;
  const FacultyODRequestsPage({Key? key, required this.facultyId}) : super(key: key);

  @override
  State<FacultyODRequestsPage> createState() => _FacultyODRequestsPageState();
}

class _FacultyODRequestsPageState extends State<FacultyODRequestsPage> {
  String _facultyRole = 'faculty';
  String _facultyDept = '';
  bool _loadingRole = true;

  @override
  void initState() {
    super.initState();
    _checkFacultyDetails();
  }

  Future<void> _checkFacultyDetails() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('faculties')
          .collection('all_faculties')
          .doc(widget.facultyId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        setState(() {
          _facultyRole = data['role'] ?? 'faculty';
          _facultyDept = data['department'] ?? '';
          _loadingRole = false;
        });
      } else {
        setState(() => _loadingRole = false);
      }
    } catch (e) {
      setState(() => _loadingRole = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingRole) {
      return const Scaffold(
        backgroundColor: Color(0xFFFF7F50),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'OD REQUESTS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: ODRequestsTab(
        facultyId: widget.facultyId,
        role: _facultyRole,
        department: _facultyDept,
      ),
    );
  }
}

// ── MY MENTEES LIST TAB ───────────────────────────────────────────────────────
// ── MY MENTEES LIST TAB ───────────────────────────────────────────────────────
class MenteesListTab extends StatefulWidget {
  final String facultyId;
  const MenteesListTab({Key? key, required this.facultyId}) : super(key: key);

  @override
  State<MenteesListTab> createState() => _MenteesListTabState();
}

class _MenteesListTabState extends State<MenteesListTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<Map<String, double>> _getStudentStats(String studentId, Map<String, dynamic> studentData) async {
    try {
      String currentSemester = 'V';
      final department = studentData['department'];
      final className = studentData['class'];

      if (department != null && className != null) {
        final classDoc = await FirebaseFirestore.instance
            .collection('colleges')
            .doc('departments')
            .collection('all_departments')
            .doc(department)
            .collection('clasees')
            .doc(className)
            .get();

        if (classDoc.exists) {
          final classData = classDoc.data()!;
          final semesterField = classData['currentSemester'];
          if (semesterField is Map) {
            currentSemester = semesterField['semester']?.toString() ?? currentSemester;
          } else if (semesterField != null) {
            currentSemester = semesterField.toString();
          }
        }
      }

      final attendanceDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(studentId)
          .collection('attendance')
          .doc(currentSemester)
          .get();

      if (attendanceDoc.exists && attendanceDoc.data() != null) {
        final attendanceData = attendanceDoc.data()!;
        int totalPeriods = 0;
        int presentCount = 0;
        int absentCount = 0;
        int odCount = 0;

        attendanceData.forEach((key, value) {
          if (key == 'P' || key == 'A' || key == 'OD') return;
          if (value is Map) {
            value.forEach((hourStr, subjectMap) {
              if (subjectMap is Map) {
                subjectMap.forEach((subject, status) {
                  totalPeriods++;
                  final stat = status.toString().toUpperCase();
                  if (stat == 'P') {
                    presentCount++;
                  } else if (stat == 'A') {
                    absentCount++;
                  } else if (stat == 'OD') {
                    odCount++;
                  }
                });
              }
            });
          }
        });

        if (totalPeriods > 0) {
          return {
            'P': (presentCount / totalPeriods) * 100,
            'A': (absentCount / totalPeriods) * 100,
            'OD': (odCount / totalPeriods) * 100,
          };
        }
      }
    } catch (_) {}
    return {'P': 0.0, 'A': 0.0, 'OD': 0.0};
  }

  Widget _buildTableHeaderCell(String text, {bool alignCenter = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        textAlign: alignCenter ? TextAlign.center : TextAlign.left,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 11,
          color: Color(0xFFFF7F50),
        ),
      ),
    );
  }

  Widget _buildStudentInfoCell(String studentId, Map<String, dynamic> data) {
    final name = data['name'] ?? 'Unknown';
    final className = data['class'] ?? '-';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 2),
          Text(
            '$studentId • $className',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCell(String studentId, Map<String, dynamic> data, String type) {
    return FutureBuilder<Map<String, double>>(
      future: _getStudentStats(studentId, data),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: Center(
              child: SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFFFF7F50)),
              ),
            ),
          );
        }

        final pct = snapshot.data![type] ?? 0.0;
        Color color = Colors.green;
        if (type == 'A') {
          color = Colors.red;
        } else if (type == 'OD') {
          color = Colors.blue;
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Center(
            child: Text(
              '${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: color,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: "Search mentees...",
                hintStyle: TextStyle(fontSize: 14, color: Colors.grey),
                border: InputBorder.none,
                prefixIcon: Icon(Icons.search, color: Colors.grey),
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val.trim().toLowerCase());
              },
            ),
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('colleges')
                .doc('students')
                .collection('all_students')
                .where('mentor_id', isEqualTo: widget.facultyId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F50)));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("No mentees assigned to you.",
                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                );
              }

              final docs = snapshot.data!.docs.where((doc) {
                final name = (doc.get('name') ?? '').toString().toLowerCase();
                final id = doc.id.toLowerCase();
                return name.contains(_searchQuery) || id.contains(_searchQuery);
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                  child: Text("No matching mentees found.", style: TextStyle(color: Colors.grey)),
                );
              }

              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Table(
                        columnWidths: const {
                          0: FlexColumnWidth(2.6),
                          1: FlexColumnWidth(1.2),
                          2: FlexColumnWidth(1.2),
                          3: FlexColumnWidth(1.2),
                        },
                        border: TableBorder(
                          horizontalInside: BorderSide(color: Colors.grey.shade100, width: 1),
                        ),
                        children: [
                          TableRow(
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF5F0),
                            ),
                            children: [
                              _buildTableHeaderCell('Student Details'),
                              _buildTableHeaderCell('Present', alignCenter: true),
                              _buildTableHeaderCell('Absent', alignCenter: true),
                              _buildTableHeaderCell('OD', alignCenter: true),
                            ],
                          ),
                          ...docs.map((studentDoc) {
                            final data = studentDoc.data() as Map<String, dynamic>;
                            final studentId = studentDoc.id;
                            return TableRow(
                              children: [
                                _buildStudentInfoCell(studentId, data),
                                _buildStatCell(studentId, data, 'P'),
                                _buildStatCell(studentId, data, 'A'),
                                _buildStatCell(studentId, data, 'OD'),
                              ],
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ODRequestsTab extends StatefulWidget {
  final String facultyId;
  final String role;
  final String department;
  const ODRequestsTab({
    Key? key,
    required this.facultyId,
    required this.role,
    required this.department,
  }) : super(key: key);

  @override
  State<ODRequestsTab> createState() => _ODRequestsTabState();
}

class _ODRequestsTabState extends State<ODRequestsTab> {
  int _selectedSegment = 0; // 0 = Pending Requests, 1 = OD History

  Future<void> _processApproval(Map<String, dynamic> request, bool approve) async {
    final reqId = request['id'];
    final studentId = request['studentId'];
    final currentStatus = request['status'];
    final fromDate = request['fromDate'];
    final toDate = request['toDate'];
    final durationType = request['durationType'];
    final periods = List<int>.from(request['periods'] ?? []);

    String comments = '';
    if (!approve) {
      final TextEditingController commentController = TextEditingController();
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Reject OD Request'),
          content: TextField(
            controller: commentController,
            decoration: const InputDecoration(
              hintText: 'Enter reason/comments for rejection...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reject', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
      if (proceed != true) return;
      comments = commentController.text.trim();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (currentStatus == 'pending_mentor') {
        if (approve) {
          await FirebaseFirestore.instance
              .collection('colleges')
              .doc('od_requests')
              .collection('all_requests')
              .doc(reqId)
              .update({
            'status': 'pending_hod',
            'mentorApproved': true,
          });
        } else {
          await FirebaseFirestore.instance
              .collection('colleges')
              .doc('od_requests')
              .collection('all_requests')
              .doc(reqId)
              .update({
            'status': 'rejected_mentor',
            'comments': comments,
          });
        }
      } else if (currentStatus == 'pending_hod') {
        if (approve) {
          await FirebaseFirestore.instance
              .collection('colleges')
              .doc('od_requests')
              .collection('all_requests')
              .doc(reqId)
              .update({
            'status': 'approved',
            'hodApproved': true,
          });

          String currentSemester = 'V';
          final studentDoc = await FirebaseFirestore.instance
              .collection('colleges')
              .doc('students')
              .collection('all_students')
              .doc(studentId)
              .get();

          if (studentDoc.exists && studentDoc.data() != null) {
            final studentData = studentDoc.data()!;
            final department = studentData['department'];
            final className = studentData['class'];

            if (department != null && className != null) {
              final classDoc = await FirebaseFirestore.instance
                  .collection('colleges')
                  .doc('departments')
                  .collection('all_departments')
                  .doc(department)
                  .collection('clasees')
                  .doc(className)
                  .get();

              if (classDoc.exists) {
                final classData = classDoc.data()!;
                final semesterField = classData['currentSemester'];
                if (semesterField is Map) {
                  currentSemester = semesterField['semester']?.toString() ?? currentSemester;
                } else if (semesterField != null) {
                  currentSemester = semesterField.toString();
                }
              }
            }
          }

          DateTime start = DateTime.parse(fromDate);
          DateTime end = DateTime.parse(toDate);
          int days = end.difference(start).inDays + 1;

          final attDocRef = FirebaseFirestore.instance
              .collection('colleges')
              .doc('students')
              .collection('all_students')
              .doc(studentId)
              .collection('attendance')
              .doc(currentSemester);

          final attDocSnap = await attDocRef.get();
          Map<String, dynamic> attendanceUpdate = {};
          if (attDocSnap.exists && attDocSnap.data() != null) {
            attendanceUpdate = attDocSnap.data()!;
          }

          for (int i = 0; i < days; i++) {
            String dateStr = DateFormat('yyyy-MM-dd').format(start.add(Duration(days: i)));
            Map<String, dynamic> dateMap = {};
            if (attendanceUpdate.containsKey(dateStr)) {
              final existing = attendanceUpdate[dateStr];
              if (existing is Map) {
                dateMap = Map<String, dynamic>.from(existing);
              }
            }

            if (durationType == 'Full Day') {
              for (int period = 1; period <= 8; period++) {
                String pStr = period.toString();
                Map<String, dynamic> pMap = {};
                if (dateMap.containsKey(pStr)) {
                  final exp = dateMap[pStr];
                  if (exp is Map) {
                    pMap = Map<String, dynamic>.from(exp);
                  }
                }
                if (pMap.keys.isNotEmpty) {
                  String subKey = pMap.keys.first;
                  pMap[subKey] = 'OD';
                  dateMap[pStr] = pMap;
                }
              }
            } else {
              for (int period in periods) {
                String pStr = period.toString();
                Map<String, dynamic> pMap = {};
                if (dateMap.containsKey(pStr)) {
                  final exp = dateMap[pStr];
                  if (exp is Map) {
                    pMap = Map<String, dynamic>.from(exp);
                  }
                }
                if (pMap.keys.isNotEmpty) {
                  String subKey = pMap.keys.first;
                  pMap[subKey] = 'OD';
                  dateMap[pStr] = pMap;
                }
              }
            }
            attendanceUpdate[dateStr] = dateMap;
          }

          await attDocRef.set(attendanceUpdate);
        } else {
          await FirebaseFirestore.instance
              .collection('colleges')
              .doc('od_requests')
              .collection('all_requests')
              .doc(reqId)
              .update({
            'status': 'rejected_hod',
            'comments': comments,
          });
        }
      }

      Navigator.pop(context); // Dismiss loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OD Request processed successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operation failed: $e'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Widget _buildSegmentControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedSegment = 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedSegment == 0 ? const Color(0xFFFF7F50) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Pending Queue',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _selectedSegment == 0 ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedSegment = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: _selectedSegment == 1 ? const Color(0xFFFF7F50) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'OD History',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: _selectedSegment == 1 ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalTimeline(Map<String, dynamic> data) {
    final status = data['status'] ?? '';
    final mentorApproved = data['mentorApproved'] == true;
    final hodApproved = data['hodApproved'] == true;

    final timestamp = data['timestamp'] as Timestamp?;
    final mentorApprovedTime = data['mentorApprovedTime'] as Timestamp?;
    final hodApprovedTime = data['hodApprovedTime'] as Timestamp?;
    final rejectedTime = data['rejectedTime'] as Timestamp?;

    String _formatTs(Timestamp? ts) {
      if (ts == null) return '';
      return DateFormat('dd MMM\nhh:mm a').format(ts.toDate());
    }

    final s1Title = "Submitted";
    final s1Sub = timestamp != null ? _formatTs(timestamp) : "";
    final s1State = 2;

    String s2Title = "Mentor Review";
    String s2Sub = "Pending";
    int s2State = 0;
    if (status == 'rejected_mentor') {
      s2Title = "Rejected";
      s2Sub = _formatTs(rejectedTime);
      s2State = -1;
    } else if (mentorApproved) {
      s2Title = "Approved";
      s2Sub = _formatTs(mentorApprovedTime);
      s2State = 2;
    } else if (status == 'pending_mentor') {
      s2Title = "In Progress";
      s2Sub = "Reviewing";
      s2State = 1;
    }

    String s3Title = "HOD Approval";
    String s3Sub = "Pending";
    int s3State = 0;
    if (status == 'rejected_hod') {
      s3Title = "Rejected";
      s3Sub = _formatTs(rejectedTime);
      s3State = -1;
    } else if (hodApproved || status == 'approved') {
      s3Title = "Finalized";
      s3Sub = _formatTs(hodApprovedTime);
      s3State = 2;
    } else if (status == 'pending_hod') {
      s3Title = "In Progress";
      s3Sub = "Reviewing";
      s3State = 1;
    }

    Color line1Color = (s1State == 2 && s2State != 0) ? (s2State == -1 ? Colors.red : Colors.green) : Colors.grey.shade300;
    Color line2Color = (s2State == 2 && s3State != 0) ? (s3State == -1 ? Colors.red : Colors.green) : Colors.grey.shade300;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
      child: Column(
        children: [
          Row(
            children: [
              _buildStepNode(s1State),
              Expanded(child: Container(height: 3, color: line1Color)),
              _buildStepNode(s2State),
              Expanded(child: Container(height: 3, color: line2Color)),
              _buildStepNode(s3State),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildStepLabel(s1Title, s1Sub, s1State, CrossAxisAlignment.start)),
              Expanded(child: _buildStepLabel(s2Title, s2Sub, s2State, CrossAxisAlignment.center)),
              Expanded(child: _buildStepLabel(s3Title, s3Sub, s3State, CrossAxisAlignment.end)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepNode(int state) {
    Color color = Colors.grey.shade300;
    IconData icon = Icons.circle;
    double size = 18;

    if (state == 2) {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (state == 1) {
      color = Colors.orange;
      icon = Icons.pending;
    } else if (state == -1) {
      color = Colors.red;
      icon = Icons.cancel;
    }

    return Container(
      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
      child: Icon(icon, color: color, size: size),
    );
  }

  Widget _buildStepLabel(String title, String sub, int state, CrossAxisAlignment align) {
    Color titleColor = state == -1 ? Colors.red : (state == 2 ? Colors.green : (state == 1 ? Colors.orange : Colors.black54));
    TextAlign textAlign = align == CrossAxisAlignment.start ? TextAlign.left : (align == CrossAxisAlignment.end ? TextAlign.right : TextAlign.center);

    return Column(
      crossAxisAlignment: align,
      children: [
        Text(
          title,
          textAlign: textAlign,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: titleColor),
        ),
        if (sub.isNotEmpty)
          Text(
            sub,
            textAlign: textAlign,
            style: const TextStyle(fontSize: 8, color: Colors.black45, height: 1.1),
          ),
      ],
    );
  }

  void _showReasonDialog(BuildContext context, Map<String, dynamic> req, bool isHodAction, bool showActionButtons) {
    final name = req['studentName'] ?? 'Unknown';
    final studentId = req['studentId'] ?? '';
    final reason = req['reason'] ?? '';
    final leaveType = req['leaveType'] ?? 'On Duty';
    final fromDate = req['fromDate'] ?? '';
    final toDate = req['toDate'] ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'OD Application Reason',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFFF7F50)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '$name ($studentId)',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
                Text(
                  'Type: $leaveType • Dates: $fromDate ${fromDate != toDate ? "to $toDate" : ""}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                const Text(
                  "REASON DETAILS:",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45, letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    reason.toString().isEmpty ? 'No reason provided.' : reason,
                    style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.3),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showActionButtons) ...[
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _processApproval(req, false);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _processApproval(req, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        child: Text(
                          isHodAction ? 'Approve & Finalize' : 'Approve & Forward',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ] else ...[
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isHOD = widget.role == 'hod';

    return Column(
      children: [
        _buildSegmentControl(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('colleges')
                .doc('od_requests')
                .collection('all_requests')
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F50)));
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text("No OD requests found.", style: TextStyle(color: Colors.grey)),
                );
              }

              final allDocs = snapshot.data!.docs;
              List<Map<String, dynamic>> filteredRequests = [];

              for (var doc in allDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] ?? '';
                final mentorId = data['mentorId'] ?? '';
                final department = data['department'] ?? '';

                if (_selectedSegment == 0) {
                  if (isHOD) {
                    if (status == 'pending_hod' && department == widget.department) {
                      filteredRequests.add(data);
                    } else if (status == 'pending_mentor' && mentorId == widget.facultyId) {
                      filteredRequests.add(data);
                    }
                  } else {
                    if (status == 'pending_mentor' && mentorId == widget.facultyId) {
                      filteredRequests.add(data);
                    }
                  }
                } else {
                  bool matchesFaculty = isHOD ? (department == widget.department) : (mentorId == widget.facultyId);
                  bool isHistoryStatus = status == 'approved' || status == 'rejected_mentor' || status == 'rejected_hod' || (status == 'pending_hod' && !isHOD);
                  if (matchesFaculty && isHistoryStatus) {
                    filteredRequests.add(data);
                  }
                }
              }

              if (filteredRequests.isEmpty) {
                return Center(
                  child: Text(
                    _selectedSegment == 0 ? "No pending OD requests." : "No OD history available.",
                    style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                );
              }

              filteredRequests.sort((a, b) {
                final aTime = a['timestamp'] as Timestamp?;
                final bTime = b['timestamp'] as Timestamp?;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime);
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                itemCount: filteredRequests.length,
                itemBuilder: (context, idx) {
                  final req = filteredRequests[idx];
                  final name = req['studentName'] ?? 'Unknown';
                  final studentId = req['studentId'] ?? '';
                  final fromDate = req['fromDate'] ?? '';
                  final toDate = req['toDate'] ?? '';
                  final durationType = req['durationType'] ?? 'Full Day';
                  final periods = List<int>.from(req['periods'] ?? []);
                  final leaveType = req['leaveType'] ?? 'On Duty';
                  final status = req['status'] ?? '';
                  final comments = req['comments'] ?? '';

                  final bool isHodAction = status == 'pending_hod';
                  final bool showActionButtons = _selectedSegment == 0;

                  Color tagColor = Colors.orange;
                  String tagText = isHodAction ? 'HOD QUEUE' : 'MENTOR QUEUE';
                  if (_selectedSegment == 1) {
                    if (status == 'approved') {
                      tagColor = Colors.green;
                      tagText = 'APPROVED';
                    } else if (status.toString().startsWith('rejected')) {
                      tagColor = Colors.red;
                      tagText = 'REJECTED';
                    } else if (status == 'pending_hod') {
                      tagColor = Colors.purple;
                      tagText = 'MENTOR APPROVED';
                    }
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    color: Colors.white,
                    elevation: 1.5,
                    child: Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      'Roll No: $studentId • $leaveType',
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: tagColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  tagText,
                                  style: TextStyle(
                                    color: tagColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 14),
                          Text(
                            'Dates: $fromDate ${fromDate != toDate ? "to $toDate" : ""}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            durationType == 'Full Day' ? 'Duration: Full Day' : 'Periods: ${periods.join(', ')}',
                            style: const TextStyle(fontSize: 11, color: Colors.black87),
                          ),
                          const SizedBox(height: 8),
                          // View Reason button
                          SizedBox(
                            width: double.infinity,
                            height: 34,
                            child: OutlinedButton.icon(
                              onPressed: () => _showReasonDialog(context, req, isHodAction, showActionButtons),
                              icon: const Icon(Icons.visibility, size: 14),
                              label: const Text('VIEW REASON', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFFF7F50),
                                side: const BorderSide(color: Color(0xFFFF7F50)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ),
                          const Divider(height: 14),
                          _buildHorizontalTimeline(req),
                          if (comments.toString().trim().isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.red.shade100),
                              ),
                              child: Text(
                                'Comments: $comments',
                                style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
