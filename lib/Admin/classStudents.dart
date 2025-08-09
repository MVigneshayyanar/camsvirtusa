import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'adminDashboard.dart';
import 'classControl.dart'; // Import the new ClassControlPage

class ClassStudentsPage extends StatefulWidget {
  final String departmentId;
  final String className;

  const ClassStudentsPage({
    Key? key,
    required this.departmentId,
    required this.className,
  }) : super(key: key);

  @override
  State<ClassStudentsPage> createState() => _ClassStudentsPageState();
}

class _ClassStudentsPageState extends State<ClassStudentsPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> filteredStudents = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchStudents();
    _searchController.addListener(() {
      filterStudents(_searchController.text);
    });
  }

  Future<void> fetchStudents() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('students')
          .collection('all_students')
          .where('class', isEqualTo: widget.className)
          .get();

      final data = snapshot.docs.map((doc) => doc.data()).toList();

      setState(() {
        students = data;
        filteredStudents = data;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching students: $e');
      setState(() => isLoading = false);
    }
  }

  void filterStudents(String query) {
    final lowerQuery = query.toLowerCase();
    final filtered = students.where((student) {
      final name = student['name']?.toString().toLowerCase() ?? '';
      final id = student['id']?.toString().toLowerCase() ?? '';
      return name.contains(lowerQuery) || id.contains(lowerQuery);
    }).toList();

    setState(() {
      filteredStudents = filtered;
    });
  }

  void _onAddStudent() {
    _showAddStudentDialog();
  }

  void _showAddStudentDialog() {
    final TextEditingController idController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Add Student by ID"),
        content: TextField(
          controller: idController,
          decoration: const InputDecoration(labelText: "Student ID"),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Add"),
            onPressed: () async {
              final id = idController.text.trim();

              if (id.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Student ID cannot be empty")),
                );
                return;
              }

              try {
                // Get student details by ID from all_students
                final doc = await FirebaseFirestore.instance
                    .collection('colleges')
                    .doc('students')
                    .collection('all_students')
                    .doc(id)
                    .get();

                if (!doc.exists) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("No student found with this ID")),
                  );
                  return;
                }

                final studentData = doc.data()!;
                final name = studentData['name'];

                // Update class for the student
                await FirebaseFirestore.instance
                    .collection('colleges')
                    .doc('students')
                    .collection('all_students')
                    .doc(id)
                    .update({
                  'class': widget.className,
                });

                Navigator.pop(context);
                fetchStudents();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Student $name added to class successfully")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Failed to add student: $e")),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _onClassControl() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ClassControlPage(className: widget.className),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: const Color(0xFFFF7F50),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${widget.className.toUpperCase()} STUDENTS",
                style: const TextStyle(color: Colors.white),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white), // Change icon as needed
                onPressed: _onClassControl,
              ),
            ],
          ),
          centerTitle: true,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by Name or ID',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: Color(0xFFFF7F50), size: 32),
                  onPressed: _onAddStudent,
                ),
              ],
            ),
          ),
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF2D2F38),
            child: const Text(
              "STUDENT LIST",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("NAME", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text("ID", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                ? const Center(child: Text("No students found."))
                : ListView.builder(
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.orange, width: 1)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(student['name'] ?? 'Unknown')),
                      Expanded(flex: 1, child: Text(student['id'] ?? 'N/A')),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70,
        decoration: const BoxDecoration(
          color: Color(0xFFE5E5E5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Image.asset("assets/search.png", height: 26),
              onPressed: () {},
            ),
            IconButton(
              icon: Image.asset("assets/homeLogo.png", height: 32),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdminDashboard(),
                  ),
                );
              },
            ),
            IconButton(
              icon: Image.asset("assets/account.png", height: 26),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }
}