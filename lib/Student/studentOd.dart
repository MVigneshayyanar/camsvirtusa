import 'package:camsvirtusa/Student/studentProfile.dart';
import 'package:flutter/material.dart';
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
      initialDate: isFromDate ? (fromDate ?? DateTime.now()) : (toDate ?? DateTime.now()),
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
    if (fromDate != null && toDate != null && selectedLeaveType != null && reasonController.text.isNotEmpty) {
      if (selectedDurationType == 'Specific Periods' && selectedPeriods.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select at least one period.')),
        );
        return;
      }

      // Show confirmation alert
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Confirmation'),
            content: Text('On Duty Application Submitted.'),
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
        Text("Number of days:", style: TextStyle(fontSize: 16)),
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
        Text("Duration Type:", style: TextStyle(fontSize: 16)),
        DropdownButtonFormField<String>(
          value: selectedDurationType,
          onChanged: (newValue) {
            setState(() {
              selectedDurationType = newValue!;
              if (selectedDurationType == 'Full Day') {
                selectedPeriods.clear(); // Clear periods if full day is selected
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
        Text("Select Periods:", style: TextStyle(fontSize: 16)),
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
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ],
    );
  }

  Widget _buildDropdownField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Type of On Duty:", style: TextStyle(fontSize: 16)),
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
        Text("Reason:", style: TextStyle(fontSize: 16)),
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
              onPressed: _goToDashboard,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('ON DUTY FORM', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFFF7F50),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        elevation: 0,
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
                  child: const Text("APPLY", style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFF7F50),
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}