import 'package:camsvirtusa/Shared/newsScreen.dart';
import 'package:camsvirtusa/Student/studentProfile.dart';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:intl/intl.dart'; // Import for date formatting
import 'studentDashboard.dart'; // Add this import

class OnDutyFormPage extends StatefulWidget {
  final String studentId;

  const OnDutyFormPage({Key? key, required this.studentId}) : super(key: key);

  @override
  _OnDutyFormPageState createState() => _OnDutyFormPageState();
}

class _OnDutyFormPageState extends State<OnDutyFormPage> {
  DateTime? fromDate;
  DateTime? toDate;
  int numberOfDays = 0;
  String? selectedLeaveType;
  String selectedDurationType = 'Full Day'; // New field for duration type
  List<int> selectedPeriods = []; // For storing selected periods

  final List<String> leaveTypes = [
    'National Cadet Corps',
    'National Service Scheme',
    'Internship',
    'Employment',
    'Symposium',
    'Workshops and Conferences',
    'OTHERS',
  ];

  final List<String> durationTypes = ['Full Day', 'Specific Periods'];

  final TextEditingController reasonController = TextEditingController();

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

  void _submitForm() {
    if (fromDate != null &&
        toDate != null &&
        selectedLeaveType != null &&
        reasonController.text.isNotEmpty) {
      if (selectedDurationType == 'Specific Periods' &&
          selectedPeriods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select at least one period.')),
        );
        return;
      }

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
                    "OD Submitted",
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
                    "On Duty Application Submitted successfully.",
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

  Widget _buildDateField(String label, bool isFromDate) {
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
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          controller: TextEditingController(
            text: isFromDate
                ? (fromDate == null
                    ? ''
                    : DateFormat('dd/MM/yyyy').format(fromDate!))
                : (toDate == null
                    ? ''
                    : DateFormat('dd/MM/yyyy').format(toDate!)),
          ),
        ),
      ],
    );
  }

  Widget _buildNumberOfDaysField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Number of days:",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: "0",
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          controller: TextEditingController(text: numberOfDays.toString()),
        ),
      ],
    );
  }

  Widget _buildDurationTypeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Duration Type:",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        DropdownButtonFormField<String>(
          value: selectedDurationType,
          onChanged: (newValue) {
            setState(() {
              selectedDurationType = newValue!;
              if (selectedDurationType == 'Full Day') {
                selectedPeriods
                    .clear(); // Clear periods if full day is selected
              }
            });
          },
          items: durationTypes.map((String type) {
            return DropdownMenuItem<String>(
              value: type,
              child: Text(type),
            );
          }).toList(),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodSelectionField() {
    if (selectedDurationType != 'Specific Periods') {
      return SizedBox.shrink(); // Hide if not specific periods
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Select Periods:",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        Wrap(
          spacing: 3,
          runSpacing: 8,
          children: List.generate(7, (index) {
            int period = index + 1;
            bool isSelected = selectedPeriods.contains(period);

            return FilterChip(
              label: Text('$period'),
              selected: isSelected,
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    selectedPeriods.add(period);
                  } else {
                    selectedPeriods.remove(period);
                  }
                  selectedPeriods.sort(); // Keep periods sorted
                });
              },
              backgroundColor: Colors.white,
              selectedColor: Color(0xFFFF7F50).withOpacity(0.3),
              checkmarkColor: Color(0xFFFF7F50),
            );
          }),
        ),
        if (selectedPeriods.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            'Selected: ${selectedPeriods.map((p) => 'Period $p').join(', ')}',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Type of On Duty:",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
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
            fillColor: Colors.white,
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
        Text("Reason:",
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        TextField(
          controller: reasonController,
          maxLines: 8,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF7F50),
        title: const Text('ON DUTY FORM'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDateField("From:", true),
              const SizedBox(height: 10),
              _buildDateField("To:", false),
              const SizedBox(height: 10),
              _buildNumberOfDaysField(),
              const SizedBox(height: 10),
              _buildDurationTypeField(),
              const SizedBox(height: 10),
              _buildPeriodSelectionField(),
              const SizedBox(height: 10),
              _buildDropdownField(),
              const SizedBox(height: 10),
              _buildReasonField(),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: _submitForm,
                  child: const Text("APPLY",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
