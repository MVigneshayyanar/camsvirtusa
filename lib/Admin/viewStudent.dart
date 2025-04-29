import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ViewStudent extends StatefulWidget {
  const ViewStudent({Key? key}) : super(key: key);

  @override
  _ViewStudentState createState() => _ViewStudentState();
}

class _ViewStudentState extends State<ViewStudent> {
  final TextEditingController _searchController = TextEditingController();
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VIEW STUDENTS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black), // Back button color
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.black),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Container(
        color: const Color(0xFF76C7C0), // Light Teal Background
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchField(),
            const SizedBox(height: 10),
            Expanded(child: _buildStudentList()),
          ],
        ),
      ),
    );
  }

  /// 🔍 Search Bar UI
  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() => searchQuery = value.trim().toLowerCase());
      },
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: "Search by Name, ID, or Dept",
        labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        prefixIcon: const Icon(Icons.search, color: Colors.black),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// 📜 Display Student List
  Widget _buildStudentList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('students').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No students found", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)));
        }

        // 📌 Filter students based on search query
        var students = snapshot.data!.docs.where((doc) {
          var student = doc.data() as Map<String, dynamic>;
          String name = student['name'].toString().toLowerCase();
          String id = student['studentId'].toString().toLowerCase();
          String dept = student['department'].toString().toLowerCase();
          return name.contains(searchQuery) || id.contains(searchQuery) || dept.contains(searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: students.length,
          itemBuilder: (context, index) {
            var student = students[index].data() as Map<String, dynamic>;
            return _buildStudentCard(student);
          },
        );
      },
    );
  }

  /// 🎓 Student Card UI (No Profile Picture)
  Widget _buildStudentCard(Map<String, dynamic> student) {
    return Card(
      color: Colors.white, // White card background
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      child: ListTile(
        title: Text(
          student['name'],
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
        ),
        subtitle: Text(
          "Dept: ${student['department']} | Year: ${student['yearSection']}",
          style: const TextStyle(color: Colors.black87),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.arrow_forward_ios, color: Colors.black),
          onPressed: () {
            _showStudentDetails(student);
          },
        ),
      ),
    );
  }

  /// 🏷 Show Student Details in a Dialog
  void _showStudentDetails(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Student Details", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStudentRow("NAME", student['name']),
              _buildStudentRow("ID", student['studentId']),
              _buildStudentRow("DEPT", student['department']),
              _buildStudentRow("YEAR & SECT", student['yearSection']),
              _buildStudentRow("PHONE", student['phone']),
              _buildStudentRow("MAIL", student['email']),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CLOSE", style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  /// 📌 Student Info Row
  Widget _buildStudentRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
            ),
          ),
          Expanded(
            flex: 5,
            child: Container(
              padding: const EdgeInsets.all(10),
              color: Colors.white,
              child: Text(value, style: const TextStyle(fontSize: 16, color: Colors.black)),
            ),
          ),
        ],
      ),
    );
  }
}
