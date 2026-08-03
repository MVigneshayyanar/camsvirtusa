import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'MarkEventAttendance.dart';

class FacultyEventsPage extends StatefulWidget {
  final String facultyId;
  const FacultyEventsPage({super.key, required this.facultyId});

  @override
  State<FacultyEventsPage> createState() => _FacultyEventsPageState();
}

class _FacultyEventsPageState extends State<FacultyEventsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        elevation: 0,
        title: const Text(
          'MY EVENTS',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('colleges')
            .doc('events')
            .collection('all_events')
            .where('assignedFacultyIds', arrayContains: widget.facultyId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F50)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No events assigned to you.",
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            );
          }

          final events = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final doc = events[index];
              final data = doc.data() as Map<String, dynamic>;
              final eventId = doc.id;
              final name = data['name'] ?? 'Unknown Event';
              final startDate = data['startDate'] ?? '';
              final endDate = data['endDate'] ?? '';
              final students = List<String>.from(data['assignedStudents'] ?? []);
              final durationType = data['durationType'] ?? 'hour';
              final selectedPeriods = List<int>.from(data['selectedPeriods'] ?? [1]);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFF7F50).withOpacity(0.1),
                    child: const Icon(PhosphorIconsRegular.calendarStar, color: Color(0xFFFF7F50)),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('$startDate to $endDate\nStudents: ${students.length}'),
                  trailing: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MarkEventAttendance(
                            eventId: eventId,
                            eventName: name,
                            students: students,
                            durationType: durationType,
                            selectedPeriods: selectedPeriods,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7F50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Mark\nAttendance', textAlign: TextAlign.center, style: TextStyle(fontSize: 10)),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
