import 'package:camsvirtusa/Student/studentProfile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaveApplicationForm extends StatefulWidget {
  final String studentId;
  const LeaveApplicationForm({Key? key, required this.studentId}) : super(key: key);

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
      initialDate: isFromDate ? (fromDate ?? DateTime.now()) : (toDate ?? DateTime.now()),
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
    if (fromDate != null && toDate != null && selectedLeaveType != null && reasonController.text.isNotEmpty) {
      // Show confirmation alert
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Confirmation'),
            content: Text('Leave Application Submitted.'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _orange,
        title: Text(
          "LEAVE FORM",
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true, // This centers the title
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
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDateField({required String label, required DateTime? date, required bool isFromDate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 16)),
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
          controller: TextEditingController(text: date == null ? '' : DateFormat('dd/MM/yyyy').format(date)),
        ),
      ],
    );
  }

  Widget _buildNumberOfDaysField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Number of Days:", style: TextStyle(fontSize: 16)),
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
        Text("Type of Leave:", style: TextStyle(fontSize: 16)),
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
        Text("Reason:", style: TextStyle(fontSize: 16)),
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
        padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30), // Added horizontal padding
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _submitForm,
      child: Text("APPLY", style: TextStyle(color: Colors.white)),
    );
  }

  Widget _buildBottomNavigationBar() {
    final mediaQuery = MediaQuery.of(context);
    final double bottomSafeArea = mediaQuery.padding.bottom;
    final double screenWidth = mediaQuery.size.width;

    return Container(
      height: 70 + bottomSafeArea, // Add safe area to prevent overlap
      decoration: BoxDecoration(
        color: const Color(0xFFE5E5E5),
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSafeArea), // Add bottom padding for safe area
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Image.asset(
                "assets/search.png",
                height: screenWidth > 600 ? 30 : 26, // Responsive height
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: Image.asset(
                "assets/homeLogo.png",
                height: screenWidth > 600 ? 36 : 32, // Responsive height
              ),
              onPressed: () {},
            ),
            IconButton(
              icon: Image.asset(
                "assets/account.png",
                height: screenWidth > 600 ? 30 : 26, // Responsive height
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentProfile(studentId: widget.studentId),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}