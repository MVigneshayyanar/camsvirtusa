import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import for date formatting

class OnDutyFormPage extends StatefulWidget {
  @override
  _OnDutyFormPageState createState() => _OnDutyFormPageState();
}

class _OnDutyFormPageState extends State<OnDutyFormPage> {
  DateTime? fromDate;
  DateTime? toDate;
  int numberOfDays = 0;
  String? selectedLeaveType;

  final List<String> leaveTypes = [
    'National Cadet Corps',
    'National Service Scheme',
    'Internship',
    'Employment',
    'Symposium',
    'Workshops and Conferences',
    'OTHERS',
  ];

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
      // Customizing the date range display, makes it easier to scroll
      helpText: 'Select the date',
      confirmText: 'Choose',
      cancelText: 'Cancel',
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

  Widget _buildDateField(String label, bool isFromDate) {
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
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          controller: TextEditingController(
            text: isFromDate
                ? (fromDate == null ? '' : DateFormat('dd/MM/yyyy').format(fromDate!))
                : (toDate == null ? '' : DateFormat('dd/MM/yyyy').format(toDate!)),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberOfDaysField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Number of days:", style: TextStyle(color: Colors.black)),  // Added title here
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: "0", // Updated hint
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          controller: TextEditingController(text: numberOfDays.toString()),
        ),
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Type of Leave:", style: TextStyle(color: Colors.black)),
        DropdownButtonFormField<String>(
          value: selectedLeaveType,
          onChanged: (newValue) {
            setState(() {
              selectedLeaveType = newValue;
            });
          },
          items: leaveTypes.map((String leave) {
            return DropdownMenuItem<String>(
              value: leave,
              child: Text(leave),
            );
          }).toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Color(0xFFD3D3D3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        TextField(
          maxLines: 10, // Increased height
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            hintText: 'Enter your reason here...',
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      height: 70,
      decoration: BoxDecoration(
        color: Color(0xFFE5E5E5),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Center(
          child: Text('ON DUTY FORM', style: TextStyle(color: Colors.white)),
        ),
        backgroundColor: const Color(0xFFFF7F50),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildDateField("From:", true),
            const SizedBox(height: 10),
            _buildDateField("To:", false),
            const SizedBox(height: 10),
            _buildNumberOfDaysField(),
            const SizedBox(height: 10),
            _buildDropdownField(),
            const SizedBox(height: 10),
            _buildReasonField(),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                // Implement the apply button functionality
              },
              child: const Text("APPLY"),
              style: ElevatedButton.styleFrom( backgroundColor: Color(0xFFFF7F50)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}