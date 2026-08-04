import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OnDutyFormPage extends StatefulWidget {
  final String studentId;
  const OnDutyFormPage({Key? key, required this.studentId}) : super(key: key);

  @override
  _OnDutyFormPageState createState() => _OnDutyFormPageState();
}

class _OnDutyFormPageState extends State<OnDutyFormPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  DateTime? fromDate;
  DateTime? toDate;
  int numberOfDays = 0;
  String? selectedLeaveType;
  String selectedDurationType = 'full_day';
  List<int> selectedPeriods = [];
  bool isEventLocked = false;

  final List<String> leaveTypes = [
    'National Cadet Corps',
    'National Service Scheme',
    'Internship',
    'Employment',
    'Symposium',
    'Workshops and Conferences',
    'OTHERS',
  ];

  final List<String> durationTypes = ['hour', 'hours', 'full_day', 'multiple_days'];
  final Map<String, String> durationLabels = {
    'hour': 'Single Hour',
    'hours': 'Multiple Hours',
    'full_day': 'Full Day',
    'multiple_days': 'Multiple Days'
  };
  final TextEditingController reasonController = TextEditingController();

  List<Map<String, dynamic>> availableEvents = [];
  String? selectedEventId;
  String? selectedEventName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchEvents();
  }

  Future<void> _fetchEvents() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('events')
          .collection('all_events')
          .where('assignedStudents', arrayContains: widget.studentId)
          .get();
      
      setState(() {
        availableEvents = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
      });
    } catch (e) {
      debugPrint("Error fetching events: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  void _calculateDays() {
    if (fromDate != null && toDate != null) {
      setState(() {
        numberOfDays = toDate!.difference(fromDate!).inDays + 1;
      });
    }
  }

  Future<void> _selectDate(BuildContext context, bool isFromDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isFromDate
          ? (fromDate ?? DateTime.now())
          : (toDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFFFF7F50),
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
        } else {
          toDate = picked;
        }
        _calculateDays();
      });
    }
  }

  Future<void> _submitForm() async {
    if (fromDate == null ||
        toDate == null ||
        selectedLeaveType == null ||
        reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields correctly.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if ((selectedDurationType == 'hour' || selectedDurationType == 'hours') && selectedPeriods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one period.'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F50))),
    );

    try {
      final studentDoc = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .doc(widget.studentId)
          .get();

      if (!studentDoc.exists) throw Exception("Student profile not found");
      final studentData = studentDoc.data()!;
      final mentorId = studentData['mentor_id'] ?? '';
      final studentName = studentData['name'] ?? '';
      final department = studentData['department'] ?? '';
      final className = studentData['class'] ?? '';

      final docRef = FirebaseFirestore.instance
          .collection('colleges')
          .doc('od_requests')
          .collection('all_requests')
          .doc();

      await docRef.set({
        'id': docRef.id,
        'studentId': widget.studentId,
        'studentName': studentName,
        'mentorId': mentorId,
        'department': department,
        'class': className,
        'fromDate': DateFormat('yyyy-MM-dd').format(fromDate!),
        'toDate': DateFormat('yyyy-MM-dd').format(toDate!),
        'durationType': selectedDurationType,
        'periods': selectedPeriods,
        'leaveType': selectedLeaveType,
        'reason': reasonController.text.trim(),
        'status': 'pending_mentor',
        'mentorApproved': false,
        'hodApproved': false,
        'timestamp': FieldValue.serverTimestamp(),
        if (selectedEventId != null) 'eventId': selectedEventId,
        if (selectedEventName != null) 'eventName': selectedEventName,
      });

      Navigator.of(context).pop(); // Dismiss loader

      setState(() {
        fromDate = null;
        toDate = null;
        numberOfDays = 0;
        selectedLeaveType = null;
        selectedDurationType = 'full_day';
        selectedPeriods = [];
        selectedEventId = null;
        selectedEventName = null;
        isEventLocked = false;
        reasonController.clear();
      });

      _tabController.animateTo(1); // Go to history tab

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("On Duty Application Submitted successfully."),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Dismiss loader
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // UI field builders
  Widget _buildDateField(String label, bool isFromDate) {
    final displayDate = isFromDate ? fromDate : toDate;
    return IgnorePointer(
      ignoring: isEventLocked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _selectDate(context, isFromDate),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isEventLocked ? Colors.grey.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    displayDate != null ? DateFormat('dd/MM/yyyy').format(displayDate) : 'dd/mm/yyyy',
                    style: TextStyle(color: displayDate != null ? (isEventLocked ? Colors.black54 : Colors.black87) : Colors.black38, fontSize: 14),
                  ),
                  Icon(Icons.calendar_today, size: 18, color: isEventLocked ? Colors.grey : const Color(0xFFFF7F50)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberOfDaysField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Number of Days:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(
            '$numberOfDays',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationTypeField() {
    return IgnorePointer(
      ignoring: isEventLocked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Duration Type:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 3.5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: durationTypes.map((type) {
              final isSelected = selectedDurationType == type;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedDurationType = type;
                    if (type == 'hour') selectedPeriods = [1];
                    else selectedPeriods = [];
                    if (type != 'multiple_days') toDate = fromDate;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFFF5F0) : (isEventLocked ? Colors.grey.shade100 : Colors.white),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isSelected ? const Color(0xFFFF7F50) : Colors.grey.shade300, width: isSelected ? 1.5 : 1),
                  ),
                  child: Center(
                    child: Text(
                      durationLabels[type] ?? type,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? const Color(0xFFFF7F50) : (isEventLocked ? Colors.black38 : Colors.black87),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelectionField() {
    if (selectedDurationType == 'full_day' || selectedDurationType == 'multiple_days') return const SizedBox.shrink();
    return IgnorePointer(
      ignoring: isEventLocked,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(selectedDurationType == 'hour' ? "Select Period:" : "Select Continuous Periods:", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(7, (index) {
              final period = index + 1;
              final isSelected = selectedPeriods.contains(period);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selectedDurationType == 'hour') {
                      selectedPeriods = [period];
                    } else {
                      if (isSelected) {
                        selectedPeriods.remove(period);
                      } else {
                        selectedPeriods.add(period);
                        selectedPeriods.sort();
                      }
                    }
                  });
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFFFF7F50) : (isEventLocked ? Colors.grey.shade100 : Colors.white),
                    shape: BoxShape.circle,
                    border: Border.all(color: isSelected ? const Color(0xFFFF7F50) : Colors.grey.shade300),
                  ),
                  child: Center(
                    child: Text(
                      '$period',
                      style: TextStyle(
                        color: isSelected ? Colors.white : (isEventLocked ? Colors.black38 : Colors.black87),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Type of On Duty:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedLeaveType,
              hint: const Text('Select OD Type', style: TextStyle(fontSize: 14, color: Colors.black38)),
              isExpanded: true,
              items: leaveTypes.map((String type) {
                return DropdownMenuItem<String>(
                  value: type,
                  child: Text(type, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedLeaveType = value),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventSelectionField() {
    if (availableEvents.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Event (Optional):", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedEventId,
              hint: const Text('None', style: TextStyle(fontSize: 14, color: Colors.black38)),
              isExpanded: true,
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('None', style: TextStyle(fontSize: 14)),
                ),
                ...availableEvents.map((evt) {
                  return DropdownMenuItem<String>(
                    value: evt['id'] as String,
                    child: Text(evt['name'] as String, style: const TextStyle(fontSize: 14)),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  selectedEventId = value;
                  if (value != null) {
                    final evt = availableEvents.firstWhere((e) => e['id'] == value);
                    selectedEventName = evt['name'];
                    if (evt['startDate'] != null) {
                      fromDate = DateFormat('yyyy-MM-dd').parse(evt['startDate']);
                    }
                    if (evt['endDate'] != null) {
                      toDate = DateFormat('yyyy-MM-dd').parse(evt['endDate']);
                    }
                    selectedDurationType = evt['durationType'] ?? 'hour';
                    selectedPeriods = List<int>.from(evt['selectedPeriods'] ?? []);
                    isEventLocked = true;
                    _calculateDays();
                  } else {
                    selectedEventName = null;
                    isEventLocked = false;
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Reason:", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54)),
        const SizedBox(height: 6),
        TextField(
          controller: reasonController,
          maxLines: 4,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            hintText: 'Provide details about your OD request...',
            hintStyle: const TextStyle(color: Colors.black38, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFFF7F50))),
          ),
        ),
      ],
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

  void _showReasonDialog(BuildContext context, Map<String, dynamic> req) {
    final reason = req['reason'] ?? '';
    final leaveType = req['leaveType'] ?? 'On Duty';
    final fromDateStr = req['fromDate'] ?? '';
    final toDateStr = req['toDate'] ?? '';

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
                  'Type: $leaveType • Dates: $fromDateStr ${fromDateStr != toDateStr ? "to $toDateStr" : ""}',
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF7F50))),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // History List Tab
  Widget _buildHistoryTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('colleges')
          .doc('od_requests')
          .collection('all_requests')
          .where('studentId', isEqualTo: widget.studentId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F50)));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text("No previous OD applications found.", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
          );
        }

        final docs = snapshot.data!.docs.toList();
        docs.sort((a, b) {
          final aTs = a.get('timestamp') as Timestamp?;
          final bTs = b.get('timestamp') as Timestamp?;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, idx) {
            final data = docs[idx].data() as Map<String, dynamic>;
            final leaveType = data['leaveType'] ?? 'On Duty';
            final fromDateStr = data['fromDate'] ?? '';
            final toDateStr = data['toDate'] ?? '';
            final durationType = data['durationType'] ?? 'Full Day';
            final periods = List<int>.from(data['periods'] ?? []);
            final status = data['status'] ?? 'pending_mentor';
            final comments = data['comments'] ?? data['rejectReason'] ?? '';
            final eventName = data['eventName'];

            Color statusColor = Colors.orange;
            String statusText = 'PENDING MENTOR';
            if (status == 'pending_hod') {
              statusColor = Colors.purple;
              statusText = 'PENDING HOD';
            } else if (status == 'approved') {
              statusColor = Colors.green;
              statusText = 'APPROVED';
            } else if (status.toString().startsWith('rejected')) {
              statusColor = Colors.red;
              statusText = 'REJECTED';
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                                leaveType.toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (eventName != null && eventName.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Event: $eventName',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFFF7F50)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 8),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    Text(
                      'Dates: $fromDateStr ${fromDateStr != toDateStr ? "to $toDateStr" : ""}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (durationType == 'full_day' || durationType == 'multiple_days' || durationType == 'Full Day') 
                          ? 'Duration: ${durationType == 'multiple_days' ? 'Multiple Days' : 'Full Day'}' 
                          : 'Periods: ${periods.join(', ')}',
                      style: const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    // View Reason button
                    SizedBox(
                      width: double.infinity,
                      height: 34,
                      child: OutlinedButton.icon(
                        onPressed: () => _showReasonDialog(context, data),
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
                    _buildHorizontalTimeline(data),
                    if (comments.toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          'Reasoning/Comment: $comments',
                          style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.w500),
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        elevation: 0,
        title: const Text(
          'ON DUTY STATUS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'APPLY OD'),
            Tab(text: 'OD STATUS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Apply OD tab
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (selectedDurationType == 'multiple_days') ...[
                      _buildDateField("From Date:", true),
                      const SizedBox(height: 12),
                      _buildDateField("To Date:", false),
                    ] else ...[
                      _buildDateField("Date:", true), // Sets fromDate and syncs toDate
                    ],
                    const SizedBox(height: 12),
                    _buildNumberOfDaysField(),
                    const SizedBox(height: 12),
                    _buildDurationTypeField(),
                    const SizedBox(height: 12),
                    _buildPeriodSelectionField(),
                    const SizedBox(height: 12),
                    _buildDropdownField(),
                    const SizedBox(height: 12),
                    _buildEventSelectionField(),
                    const SizedBox(height: 12),
                    _buildReasonField(),
                    const SizedBox(height: 20),
                    Center(
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7F50),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text(
                            "SUBMIT APPLICATION",
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // History tab
          _buildHistoryTab(),
        ],
      ),
    );
  }
}
