import 'package:camsvirtusa/Shared/newsScreen.dart';
import 'package:camsvirtusa/Student/studentProfile.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart';
import 'studentDashboard.dart'; // Add this import

class LeaveApplicationForm extends StatefulWidget {
  final String studentId;
  const LeaveApplicationForm({Key? key, required this.studentId})
      : super(key: key);

  @override
  _LeaveApplicationFormState createState() {
    return _LeaveApplicationFormState();
  }
}

class _LeaveApplicationFormState extends State<LeaveApplicationForm> {
  DateTime? fromDate;
  DateTime? toDate;
  int numberOfDays = 0;
  String? selectedLeaveType;

  final List<String> leaveTypes = [
    'SICK LEAVE',
    'PERSONAL LEAVE',
    'RELIGIOUS HOLIDAY',
    'CASUAL LEAVE',
    'EXTENDED LEAVE',
    'SPECIAL CIRCUMSTANCES',
    'OTHERS',
  ];

  final TextEditingController reasonController = TextEditingController();

  static const Color _orange = Color(0xFFFF7F50);
  static const Color _lightGrayBg = Color(0xFFF0F0F0);
  static const Color _dropdownColor = Color(0xFFFFFFFF);

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
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          fromDate = picked;
          _calculateDays();
        } else {
          toDate = picked;
          _calculateDays();
        }
      });
    }
  }

  void _submitForm() {
    if (fromDate != null &&
        toDate != null &&
        selectedLeaveType != null &&
        reasonController.text.isNotEmpty) {
      // Show confirmation alert
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.0),
            ),
            elevation: 0,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Success Icon
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: Colors.green,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Title
                  const Text(
                    "Leave Submitted",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  // Description
                  const Text(
                    "Leave Application Submitted successfully.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  // OK Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF7F50),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "OK",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } else {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill all fields correctly.')),
      );
    }
  }

  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StudentDashboard(studentId: widget.studentId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _orange,
        title: const Text(
          "LEAVE FORM",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white), // White back arrow
          onPressed: () {
            Navigator.of(context).pop(); // Return to the previous page
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateField(label: "From:", date: fromDate, isFromDate: true),
              SizedBox(height: 10),
              _buildDateField(label: "To:", date: toDate, isFromDate: false),
              SizedBox(height: 10),
              _buildNumberOfDaysField(), // Include number of days field
              SizedBox(height: 10),
              _buildLeaveTypeDropdown(),
              SizedBox(height: 10),
              _buildReasonField(),
              SizedBox(height: 20),
              Center(child: _buildSubmitButton()), // Center the apply button
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDateField(
      {required String label,
      required DateTime? date,
      required bool isFromDate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'dd/mm/yyyy',
            suffixIcon: IconButton(
              icon: Icon(Icons.calendar_today),
              onPressed: () => _selectDate(context, isFromDate),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          controller: TextEditingController(
              text: date == null ? '' : DateFormat('dd/MM/yyyy').format(date)),
        ),
      ],
    );
  }

  Widget _buildNumberOfDaysField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Number of Days:",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
          controller: TextEditingController(text: numberOfDays.toString()),
        ),
      ],
    );
  }

  Widget _buildLeaveTypeDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Type of Leave:",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        DropdownButtonFormField<String>(
          value: selectedLeaveType,
          onChanged: (newValue) {
            setState(() {
              selectedLeaveType = newValue!;
            });
          },
          items: leaveTypes.map((String leave) {
            return DropdownMenuItem<String>(
              value: leave,
              child: Text(leave),
            );
          }).toList(),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: _dropdownColor, // Set the color of the dropdown
          ),
        ),
      ],
    );
  }

  Widget _buildReasonField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Reason:",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        TextFormField(
          controller: reasonController,
          maxLines: 10, // Increased height to 10 lines
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: 'Enter your reason here...',
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: _orange,
        padding: EdgeInsets.symmetric(
            vertical: 15, horizontal: 30), // Added horizontal padding
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _submitForm,
      child: Text("APPLY",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
    );
  }
}
