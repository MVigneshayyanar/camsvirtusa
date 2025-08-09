import 'package:camsvirtusa/Student/studentProfile.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaveApplicationForm extends StatefulWidget {

  final String studentId;
  const LeaveApplicationForm({Key? key, required this.studentId}) : super(key: key);
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
    // Get media query data for responsive design
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double screenHeight = mediaQuery.size.height;
    final double screenWidth = mediaQuery.size.width;
    final EdgeInsets viewInsets = mediaQuery.viewInsets;
    final EdgeInsets viewPadding = mediaQuery.viewPadding;
    final double bottomSafeArea = mediaQuery.padding.bottom;

    // Calculate dynamic dimensions based on screen size
    final double appBarHeight = kToolbarHeight;
    final double bottomNavHeight = 70 + bottomSafeArea;
    final double availableHeight = screenHeight - appBarHeight - bottomNavHeight - viewInsets.bottom;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _orange,
        title: Text("LEAVE FORM", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Main content area with calculated height
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth > 600 ? 32.0 : 16.0, // Responsive padding for tablets
                vertical: 16.0,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: availableHeight - 32, // Ensure minimum height minus padding
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateField(label: "From:", date: fromDate, isFromDate: true),
                    SizedBox(height: screenHeight > 600 ? 15 : 10), // Responsive spacing
                    _buildDateField(label: "To:", date: toDate, isFromDate: false),
                    SizedBox(height: screenHeight > 600 ? 15 : 10),
                    _buildNumberOfDaysField(),
                    SizedBox(height: screenHeight > 600 ? 15 : 10),
                    _buildLeaveTypeDropdown(),
                    SizedBox(height: screenHeight > 600 ? 15 : 10),
                    _buildReasonField(),
                    SizedBox(height: screenHeight > 600 ? 40 : 30),
                    // Centered APPLY button
                    Center(
                      child: _buildSubmitButton(),
                    ),
                    SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildDateField({required String label, required DateTime? date, required bool isFromDate}) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: screenWidth > 600 ? 18 : 16, // Responsive font size
          ),
        ),
        SizedBox(height: 8),
        TextField(
          readOnly: true,
          decoration: InputDecoration(
            hintText: 'dd/mm/yyyy',
            suffixIcon: IconButton(
              icon: Icon(Icons.calendar_today),
              onPressed: () => _selectDate(context, isFromDate),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: screenWidth > 600 ? 20 : 16, // Responsive padding
            ),
          ),
          style: TextStyle(fontSize: screenWidth > 600 ? 16 : 14),
          controller: TextEditingController(text: date == null ? '' : DateFormat('dd/MM/yyyy').format(date)),
        ),
      ],
    );
  }

  Widget _buildNumberOfDaysField() {
    final screenWidth = MediaQuery.of(context).size.width;

    return TextField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: "Number of Days",
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: screenWidth > 600 ? 20 : 16,
        ),
      ),
      style: TextStyle(fontSize: screenWidth > 600 ? 16 : 14),
      controller: TextEditingController(text: numberOfDays.toString()),
    );
  }

  Widget _buildLeaveTypeDropdown() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Type of Leave:",
          style: TextStyle(
            fontSize: screenWidth > 600 ? 18 : 16,
          ),
        ),
        SizedBox(height: 8),
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
              child: Text(
                leave,
                style: TextStyle(fontSize: screenWidth > 600 ? 16 : 14),
              ),
            );
          }).toList(),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: screenWidth > 600 ? 20 : 16,
            ),
          ),
          style: TextStyle(fontSize: screenWidth > 600 ? 16 : 14),
        ),
      ],
    );
  }

  Widget _buildReasonField() {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Reason:",
          style: TextStyle(
            fontSize: screenWidth > 600 ? 18 : 16,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: reasonController,
          maxLines: screenWidth > 600 ? 6 : 5, // More lines on larger screens
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            hintText: 'Enter your reason here...',
            contentPadding: EdgeInsets.all(16),
          ),
          style: TextStyle(fontSize: screenWidth > 600 ? 16 : 14),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      width: screenWidth > 600 ? 250 : 200, // Responsive button width
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _orange,
          padding: EdgeInsets.symmetric(
            vertical: screenWidth > 600 ? 18 : 15,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _submitForm,
        child: Text(
          "APPLY",
          style: TextStyle(
            color: Colors.white,
            fontSize: screenWidth > 600 ? 18 : 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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
                    builder: (_) => StudentProfile(studentId: widget.studentId),
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