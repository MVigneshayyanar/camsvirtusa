import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> filteredStudents = [];

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchController.addListener(_filterStudents);
  }

  void _filterStudents() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      filteredStudents = students.where((student) {
        return student['id'].toLowerCase().contains(query) ||
            student['name'].toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _fetchStudents() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("colleges")
        .doc("students")
        .collection("all_students")
        .where("class", isEqualTo: widget.className)
        .get();

    final List<Map<String, dynamic>> loaded = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': data['id'] ?? '',
        'name': data['name'] ?? '',
      };
    }).toList();

    setState(() {
      students = loaded;
      filteredStudents = loaded;
    });
  }

  Future<void> _addStudent(String id) async {
    if (id.isEmpty) return;

    final studentRef = FirebaseFirestore.instance
        .collection("colleges")
        .doc("students")
        .collection("all_students")
        .doc(id);

    final doc = await studentRef.get();

    if (doc.exists) {
      await studentRef.update({
        "class": widget.className,
        "department": widget.departmentId,
      });

      _idController.clear();
      Navigator.pop(context); // Close the dialog on success
      _fetchStudents(); // Refresh list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Student ID not found")),
      );
    }
  }

  void _showAddStudentPopup() {
    _idController.clear();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add Student by ID'),
        content: TextField(
          controller: _idController,
          decoration: const InputDecoration(
            labelText: 'Student ID',
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Save'),
            onPressed: () {
              final id = _idController.text.trim();
              _addStudent(id);
            },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _idController.dispose();
    super.dispose();
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
          title: Text("${widget.className} STUDENTS",
              style: const TextStyle(color: Colors.white)),
          centerTitle: true,
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(40)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      size: 32, color: Color(0xFFFF7F50)),
                  onPressed: _showAddStudentPopup,
                ),
              ],
            ),
          ),
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF2D2F38),
            child: const Text("STUDENT LIST",
                style: TextStyle(color: Colors.white)),
          ),
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text("STUDENT ID")),
                Expanded(flex: 3, child: Text("NAME")),
              ],
            ),
          ),
          Expanded(
            child: filteredStudents.isEmpty
                ? const Center(child: Text("No students found."))
                : ListView.builder(
              itemCount: filteredStudents.length,
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border:
                    Border(bottom: BorderSide(color: Colors.orange)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(student['id'])),
                      Expanded(flex: 3, child: Text(student['name'])),
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
                Navigator.popUntil(
                    context, ModalRoute.withName("/admin_dashboard"));
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
