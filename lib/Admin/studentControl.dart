import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'adminDashboard.dart';

class StudentControlPage extends StatefulWidget {
  const StudentControlPage({Key? key}) : super(key: key);

  @override
  State<StudentControlPage> createState() => _StudentControlPageState();
}

class _StudentControlPageState extends State<StudentControlPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  Map<String, String> _mentorNames = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final studentSnapshot = await FirebaseFirestore.instance
          .collection("colleges")
          .doc("students")
          .collection("all_students")
          .get();

      final facultySnapshot = await FirebaseFirestore.instance
          .collection("colleges")
          .doc("faculties")
          .collection("all_faculties")
          .get();

      _mentorNames = {
        for (var doc in facultySnapshot.docs)
          doc.id: (doc.data()['name'] ?? 'Unknown').toString()
      };

      final students = studentSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          ...data,
          'docId': doc.id,
          'mentor_name': _mentorNames[data['mentor_id']] ?? 'Unknown',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _allStudents = students;
          _filteredStudents = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching students: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredStudents = _allStudents.where((student) {
        final name = (student['name'] ?? '').toString().toLowerCase();
        final id = (student['id'] ?? '').toString().toLowerCase();
        return name.contains(query) || id.contains(query);
      }).toList();
    });
  }

  void _showStudentDetailsPopup(Map<String, dynamic> student, String docId) async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection("colleges")
        .doc("students")
        .collection("all_students")
        .doc(docId)
        .get();

    final data = docSnapshot.data();
    if (data == null) return;

    final nameController = TextEditingController(text: data['name'] ?? '');
    final emailController = TextEditingController(text: data['email'] ?? '');
    final deptController = TextEditingController(text: data['department'] ?? '');
    final passwordController = TextEditingController(text: data['password'] ?? '');
    final mentorController = TextEditingController(text: data['mentor_id'] ?? '');
    final classController = TextEditingController(text: data['class'] ?? '');

    String mentorName = "Unknown";
    final mentorId = data['mentor_id'];
    if (mentorId != null && mentorId.toString().isNotEmpty) {
      try {
        final mentorSnapshot = await FirebaseFirestore.instance
            .collection("colleges")
            .doc("faculties")
            .collection("all_faculties")
            .doc(mentorId)
            .get();
        if (mentorSnapshot.exists) {
          mentorName = mentorSnapshot.data()?['name'] ?? "Unknown";
        }
      } catch (e) {
        debugPrint("Error fetching mentor name: $e");
      }
    }

    bool isEditing = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              titlePadding: EdgeInsets.zero,
              title: _buildDialogHeader(
                "Student Details",
                    () => Navigator.pop(context),
              ),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildReadonlyField("Student ID", data['id'] ?? ''),
                      isEditing
                          ? _buildEditableField("Name", nameController)
                          : _buildReadonlyField("Name", data['name']),
                      isEditing
                          ? _buildEditableField("Email", emailController)
                          : _buildReadonlyField("Email", data['email']),
                      isEditing
                          ? _buildEditableField("Department", deptController)
                          : _buildReadonlyField("Department", data['department']),
                      isEditing
                          ? _buildEditableField("Class", classController)
                          : _buildReadonlyField("Class", data['class']),
                      isEditing
                          ? _buildEditableField("Mentor ID", mentorController)
                          : ListTile(
                        title: const Text("Mentor"),
                        subtitle: Text("$mentorName (${data['mentor_id']})"),
                      ),
                      isEditing
                          ? _buildEditableField("Password", passwordController, obscure: true)
                          : const ListTile(
                        title: Text("Password"),
                        subtitle: Text("••••••••"),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (!isEditing)
                  TextButton(
                    child: const Text("Edit"),
                    onPressed: () => setDialogState(() => isEditing = true),
                  ),
                if (isEditing) ...[
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Confirm Delete"),
                          content: const Text("Are you sure you want to delete this student?"),
                          actions: [
                            TextButton(
                              child: const Text("Cancel"),
                              onPressed: () => Navigator.pop(context, false),
                            ),
                            ElevatedButton(
                              child: const Text("Delete"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () => Navigator.pop(context, true),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await FirebaseFirestore.instance
                            .collection("colleges")
                            .doc("students")
                            .collection("all_students")
                            .doc(docId)
                            .delete();
                        Navigator.pop(context);
                        _fetchStudents();
                      }
                    },
                    child: const Text(
                      "Delete",
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    child: const Text("Save"),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection("colleges")
                          .doc("students")
                          .collection("all_students")
                          .doc(docId)
                          .update({
                        "name": nameController.text.trim(),
                        "email": emailController.text.trim(),
                        "department": deptController.text.trim(),
                        "class": classController.text.trim(),
                        "mentor_id": mentorController.text.trim(),
                        "password": passwordController.text.trim(),
                      });
                      Navigator.pop(context);
                      _fetchStudents();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7F50),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildReadonlyField(String label, String? value) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(value ?? 'N/A'),
    );
  }

  Widget _buildEditableField(String label, TextEditingController controller, {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget _buildDialogHeader(String title, VoidCallback onClose) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFFF7F50),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context) {
    final _idController = TextEditingController();
    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    final _departmentController = TextEditingController();
    final _mentorController = TextEditingController();
    final _classController = TextEditingController();
    final _passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        elevation: 8,
        titlePadding: EdgeInsets.zero,
        title: _buildDialogHeader("Add New Student", () => Navigator.pop(context)),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Student ID'),
              ),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: _departmentController,
                decoration: const InputDecoration(labelText: 'Department'),
              ),
              TextField(
                controller: _classController,
                decoration: const InputDecoration(labelText: 'Class'),
              ),
              TextField(
                controller: _mentorController,
                decoration: const InputDecoration(labelText: 'Mentor ID'),
              ),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Add'),
            onPressed: () async {
              final id = _idController.text.trim();
              final name = _nameController.text.trim();
              if (id.isEmpty || name.isEmpty) return;

              final email = _emailController.text.trim();
              final dept = _departmentController.text.trim();
              final mentor = _mentorController.text.trim();
              final studentClass = _classController.text.trim();
              final password = _passwordController.text.trim();

              await FirebaseFirestore.instance
                  .collection("colleges")
                  .doc("students")
                  .collection("all_students")
                  .doc(id)
                  .set({
                "id": id,
                "name": name,
                "email": email,
                "department": dept,
                "class": studentClass,
                "mentor_id": mentor,
                "password": password,
              });

              Navigator.pop(context);
              _fetchStudents();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: AppBar(
          backgroundColor: const Color(0xFFFF7F50),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            "STUDENT CONTROL",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.refresh, color: Colors.white),
              onPressed: _isLoading ? null : _fetchStudents,
            ),
          ],
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
                      hintText: 'Search by ID or Name',
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
                  icon: const Icon(
                    Icons.add_circle,
                    size: 32,
                    color: Color(0xFFFF7F50),
                  ),
                  onPressed: () => _showAddStudentDialog(context),
                ),
              ],
            ),
          ),
          //Container(
            //alignment: Alignment.centerLeft,
            //padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            //color: const Color(0xFF2D2F38),
            //child: const Text(
              //"STUDENT INFORMATION",
              //style: TextStyle(color: Colors.white),
            //),
          //),
          Container(
            color: const Color(0xFF36454F),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("STUDENT ID", style: TextStyle(color: Colors.white))),
                Expanded(flex: 3, child: Text("NAME", style: TextStyle(color: Colors.white))),
                Expanded(flex: 1, child: Text("DETAILS", style: TextStyle(color: Colors.white))),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF7F50),
              ),
            )
                : ListView.builder(
              itemCount: _filteredStudents.length,
              itemBuilder: (context, index) {
                final student = _filteredStudents[index];
                return Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.orange, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(student['id'] ?? '')),
                      Expanded(flex: 3, child: Text(student['name'] ?? '')),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: ElevatedButton(
                            onPressed: () {
                              _showStudentDetailsPopup(student, student['docId']);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF7F50),
                              foregroundColor: Colors.white,
                              shape: const StadiumBorder(),
                              padding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 0,
                              ),
                            ),
                            child: const Text('View'),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        height: 70 + bottomPadding,
        decoration: const BoxDecoration(
          color: Color(0xFFE5E5E5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
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
      ),
    );
  }
}