import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaveApplicationForm extends StatefulWidget {
  @override
  _LeaveApplicationFormState createState() => _LeaveApplicationFormState();
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
      appBar: AppBar(
        backgroundColor: _orange,
        title: Text("LEAVE FORM", style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: Icon(Icons.menu),
          onPressed: () {
            Scaffold.of(context).openDrawer(); // Handle menu navigation
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
              _buildNumberOfDaysField(),
              SizedBox(height: 10),
              _buildLeaveTypeDropdown(),
              SizedBox(height: 10),
              _buildReasonField(),
              SizedBox(height: 20),
              _buildSubmitButton(),
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
    return TextField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: "Number of Days",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      controller: TextEditingController(text: numberOfDays.toString()),
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
          maxLines: 5,
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
        padding: EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _submitForm,
      child: Text("APPLY", style: TextStyle(color: Colors.white)),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: _lightGrayBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(icon: Icon(Icons.search), onPressed: () {}),
          IconButton(icon: Icon(Icons.home), onPressed: () {}),
          IconButton(icon: Icon(Icons.person), onPressed: () {}),
        ],
      ),
    );
  }
}