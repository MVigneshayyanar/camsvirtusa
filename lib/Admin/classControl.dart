import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassControlPage extends StatefulWidget {
  final String className; // e.g. 'seccj2028a'

  const ClassControlPage({Key? key, required this.className}) : super(key: key);

  @override
  _ClassControlPageState createState() => _ClassControlPageState();
}

class _ClassControlPageState extends State<ClassControlPage> {
  final TextEditingController _facultyIdController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();

  String? _selectedSemester;
  final List<String> _semesters = ['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X'];

  List<Map<String, dynamic>> _facultyList = [];
  Map<String, String> _facultyNames = {};

  final String collegePath = 'colleges';
  final String departmentsDoc = 'departments';
  final String allDepartmentsCollection = 'all_departments';
  final String departmentDoc = 'meicse'; // adjust if dynamic
  final String claseesCollection = 'clasees'; // confirm spelling

  @override
  void initState() {
    super.initState();
    _fetchAllFacultyNames();
  }

  Future<void> _fetchAllFacultyNames() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("colleges")
          .doc("faculties")
          .collection("all_faculties")
          .get();

      final namesMap = <String, String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        String id = doc.id;
        String name = data['name'] ?? "Unknown";
        namesMap[id] = name;
      }

      setState(() {
        _facultyNames = namesMap;
      });
    } catch (e) {
      _showSnackBar("Failed to fetch faculty names: $e");
    }
  }

  Future<DocumentReference> getClassDocRef() {
    return Future.value(FirebaseFirestore.instance
        .collection(collegePath)
        .doc(departmentsDoc)
        .collection(allDepartmentsCollection)
        .doc(departmentDoc)
        .collection(claseesCollection)
        .doc(widget.className));
  }

  Future<void> _fetchFaculty() async {
    if (_selectedSemester == null) return;

    try {
      final docRef = await getClassDocRef();
      final snapshot = await docRef.get();

      if (!snapshot.exists) {
        setState(() {
          _facultyList = [];
        });
        return;
      }

      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final facultyMap = data['faculty'] as Map<String, dynamic>? ?? {};
      final semesterFaculty = facultyMap[_selectedSemester] as List<dynamic>? ?? [];

      setState(() {
        _facultyList = semesterFaculty.map((e) => Map<String, dynamic>.from(e)).toList();
      });
    } catch (e) {
      _showSnackBar("Failed to fetch faculty: $e");
    }
  }

  Future<void> _addFaculty() async {
    final facultyId = _facultyIdController.text.trim();
    final subject = _subjectController.text.trim();

    if (_selectedSemester == null || facultyId.isEmpty || subject.isEmpty) {
      _showSnackBar("All fields are required");
      return;
    }

    try {
      final docRef = await getClassDocRef();
      final snapshot = await docRef.get();
      Map<String, dynamic> data = snapshot.exists ? snapshot.data() as Map<String, dynamic> : {};

      Map<String, dynamic> facultyMap = data['faculty'] != null
          ? Map<String, dynamic>.from(data['faculty'])
          : {};

      List<dynamic> semesterFaculty = facultyMap[_selectedSemester] != null
          ? List<dynamic>.from(facultyMap[_selectedSemester])
          : [];

      bool duplicate = semesterFaculty.any(
              (f) => f['facultyId'] == facultyId && f['subject'] == subject);

      if (duplicate) {
        _showSnackBar("Faculty with this subject already exists in selected semester");
        return;
      }

      semesterFaculty.add({
        'facultyId': facultyId,
        'subject': subject,
      });

      facultyMap[_selectedSemester!] = semesterFaculty;

      await docRef.set({'faculty': facultyMap}, SetOptions(merge: true));

      _showSnackBar("Faculty added successfully");
      _facultyIdController.clear();
      _subjectController.clear();

      await _fetchFaculty();
    } catch (e) {
      _showSnackBar("Failed to add faculty: $e");
    }
  }

  Future<void> _removeFaculty(String facultyId, String subject) async {
    if (_selectedSemester == null) return;

    try {
      final docRef = await getClassDocRef();
      final snapshot = await docRef.get();

      if (!snapshot.exists) return;

      Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> facultyMap = data['faculty'] != null
          ? Map<String, dynamic>.from(data['faculty'])
          : {};

      List<dynamic> semesterFaculty = facultyMap[_selectedSemester] != null
          ? List<dynamic>.from(facultyMap[_selectedSemester])
          : [];

      semesterFaculty.removeWhere(
              (f) => f['facultyId'] == facultyId && f['subject'] == subject);

      facultyMap[_selectedSemester!] = semesterFaculty;

      await docRef.set({'faculty': facultyMap}, SetOptions(merge: true));

      _showSnackBar("Faculty removed successfully");
      await _fetchFaculty();
    } catch (e) {
      _showSnackBar("Failed to remove faculty: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
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
          Text(title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: onClose),
        ],
      ),
    );
  }

  void _showAddFacultyDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: _buildDialogHeader("Add Faculty & Subject", () => Navigator.pop(context)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedSemester,
                    hint: const Text("Select Semester"),
                    items: _semesters.map((sem) =>
                        DropdownMenuItem(value: sem, child: Text(sem))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSemester = val;
                      });
                    },
                    decoration: const InputDecoration(
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _facultyIdController,
                    decoration: const InputDecoration(labelText: "Faculty ID"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _subjectController,
                    decoration: const InputDecoration(labelText: "Subject"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _facultyIdController.clear();
                  _subjectController.clear();
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _addFaculty();
                  Navigator.pop(context);
                },
                child: const Text("Add"),
              ),
            ],
          ),
        );
      },
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
          title: Text("${widget.className.toUpperCase()} CLASS CONTROL",
              style: const TextStyle(color: Colors.white)),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications, color: Colors.white),
              onPressed: () {},
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Add faculty button and semester selector row
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedSemester,
                    hint: const Text("Select Semester"),
                    items: _semesters
                        .map((sem) => DropdownMenuItem(value: sem, child: Text(sem)))
                        .toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedSemester = val;
                      });
                      _fetchFaculty();
                    },
                    decoration: InputDecoration(
                      contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    _showAddFacultyDialog();
                  },
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text("Add Faculty"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7F50),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  ),
                ),
              ],
            ),
          ),

          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF2D2F38),
            child: const Text("FACULTY INFORMATION",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),

          Container(
            color: Colors.black12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text("FACULTY NAME")),
                Expanded(flex: 3, child: Text("SUBJECT")),
                Expanded(flex: 1, child: Center(child: Text("REMOVE"))),
              ],
            ),
          ),

          Expanded(
            child: _facultyList.isEmpty
                ? const Center(child: Text("No faculty found"))
                : ListView.builder(
              itemCount: _facultyList.length,
              itemBuilder: (context, index) {
                final faculty = _facultyList[index];
                final facultyId = faculty['facultyId'] ?? "Unknown";
                final subject = faculty['subject'] ?? "Unknown";
                final facultyName = _facultyNames[facultyId] ?? facultyId;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.orange, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 3, child: Text(facultyName)),
                      Expanded(flex: 3, child: Text(subject)),
                      Expanded(
                        flex: 1,
                        child: Center(
                          child: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () {
                              _removeFaculty(facultyId, subject);
                            },
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
                onPressed: () {}),
            IconButton(
              icon: Image.asset("assets/homeLogo.png", height: 32),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            IconButton(
                icon: Image.asset("assets/account.png", height: 26),
                onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
