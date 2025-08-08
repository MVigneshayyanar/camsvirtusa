import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'adminDashboard.dart';

class FacultyOverviewPage extends StatefulWidget {
  const FacultyOverviewPage({Key? key}) : super(key: key);

  @override
  State<FacultyOverviewPage> createState() => _FacultyOverviewPageState();
}

class _FacultyOverviewPageState extends State<FacultyOverviewPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allFaculties = [];
  List<Map<String, dynamic>> _filteredFaculties = [];

  @override
  void initState() {
    super.initState();
    _fetchFaculties();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFaculties() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("colleges")
        .doc("faculties")
        .collection("all_faculties")
        .get();

    final faculties = snapshot.docs.map((doc) => doc.data()).toList();
    setState(() {
      _allFaculties = faculties;
      _filteredFaculties = faculties; // Initialize filtered list
    });
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFaculties = _allFaculties.where((faculty) {
        final name = (faculty['name'] ?? '').toString().toLowerCase();
        final id = (faculty['id'] ?? '').toString().toLowerCase();
        return name.contains(query) || id.contains(query);
      }).toList();
    });
  }

  Future<Map<String, String>> _fetchStudentNames(List<String> menteeIds) async {
    final Map<String, String> menteeMap = {};
    for (var id in menteeIds) {
      final doc = await FirebaseFirestore.instance
          .collection("colleges")
          .doc("students")
          .collection("all_students")
          .doc(id)
          .get();
      if (doc.exists && doc.data()?.containsKey("name") == true) {
        menteeMap[id] = doc.data()!["name"];
      }
    }
    return menteeMap;
  }

  void _showFacultyDetailsPopup(Map<String, dynamic> faculty, String docId) async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection("colleges")
        .doc("faculties")
        .collection("all_faculties")
        .doc(docId)
        .get();
    final data = docSnapshot.data();
    if (data == null) return;

    // Initialize controllers
    final nameController = TextEditingController(text: data['name']);
    final emailController = TextEditingController(text: data['email']);
    final deptController = TextEditingController(text: data['department']);
    final passwordController = TextEditingController(text: data['password'] ?? '');

    List<String> menteeIds = List<String>.from(data['mentees'] ?? []);
    List<String> classes = List<String>.from(data['classes'] ?? []);
    final menteeController = TextEditingController();
    final classController = TextEditingController();

    Map<String, String> mentees = await _fetchStudentNames(menteeIds);

    showDialog(
      context: context,
      builder: (context) {
        bool isEditing = false;

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
                  "Faculty Details",
                      () => Navigator.pop(context)
              ),
              content: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildReadonlyField("Faculty ID", data['id'] ?? ''),
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
                          ? _buildEditableField("Password", passwordController, obscure: true)
                          : const ListTile(
                          title: Text("Password"),
                          subtitle: Text("••••••••")),
                      const SizedBox(height: 20),
                      _buildListEditor(
                        title: "Mentees",
                        isEditing: isEditing,
                        itemController: menteeController,
                        items: mentees,
                        onAdd: (id) async {
                          final map = await _fetchStudentNames([id]);
                          if (map.containsKey(id)) {
                            setDialogState(() {
                              mentees[id] = map[id]!;
                            });
                          }
                        },
                        onDelete: (id) => setDialogState(() => mentees.remove(id)),
                      ),
                      const SizedBox(height: 20),
                      _buildListEditorSimple(
                        title: "Classes",
                        isEditing: isEditing,
                        items: classes,
                        itemController: classController,
                        onAdd: (val) => setDialogState(() => classes.add(val)),
                        onDelete: (val) => setDialogState(() => classes.remove(val)),
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
                          content: const Text(
                              "Are you sure you want to delete this faculty?"),
                          actions: [
                            TextButton(
                              child: const Text("Cancel"),
                              onPressed: () => Navigator.pop(context, false),
                            ),
                            ElevatedButton(
                              child: const Text("Delete"),
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7F50), // Button color
                                foregroundColor: Colors.white, // Text color
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10), // Rounded corners
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), // Padding
                              ),
                            ),


                          ],
                        ),
                      );
                      if (confirm == true) {
                        await FirebaseFirestore.instance
                            .collection("colleges")
                            .doc("faculties")
                            .collection("all_faculties")
                            .doc(docId)
                            .delete();
                        Navigator.pop(context);
                        if (mounted) {
                          setState(() {});
                        }
                      }
                    },
                    child: const Text("Delete",
                        style: TextStyle(color: Color(0xFFFF7F50))),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    child: const Text("Save"),
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection("colleges")
                          .doc("faculties")
                          .collection("all_faculties")
                          .doc(docId)
                          .update({
                        "name": nameController.text.trim(),
                        "email": emailController.text.trim(),
                        "department": deptController.text.trim(),
                        "password": passwordController.text.trim(),
                        "mentees": mentees.keys.toList(),
                        "classes": classes,
                      });
                      Navigator.pop(context);
                      if (mounted) {
                        setState(() {});
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7F50), // Button color
                      foregroundColor: Colors.white, // Text color
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10), // Rounded corners
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20), // Padding
                    ),
                  ),
                ]
              ],
            );
          },
        );
      },
    );
  }

  // --- Helper Widgets (unchanged) ---

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
          Text(title,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: onClose),
        ],
      ),
    );
  }

  Widget _buildListEditor({
    required String title,
    required bool isEditing,
    required TextEditingController itemController,
    required Map<String, String> items,
    required Function(String) onAdd,
    required Function(String) onDelete,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      if (isEditing)
        Row(children: [
          Expanded(
              child: TextField(
                  controller: itemController, decoration: const InputDecoration(hintText: "Enter ID"))),
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                final input = itemController.text.trim();
                if (input.isNotEmpty && !items.containsKey(input)) {
                  onAdd(input);
                  itemController.clear();
                }
              }),
        ]),
      if (items.isEmpty)
        const Text("None")
      else
        Column(
            children: items.entries
                .map((e) => ListTile(
              title: Text("${e.value} (${e.key})"),
              trailing: isEditing
                  ? IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => onDelete(e.key),
              )
                  : null,
            ))
                .toList()),
    ]);
  }

  Widget _buildListEditorSimple({
    required String title,
    required bool isEditing,
    required List<String> items,
    required TextEditingController itemController,
    required Function(String) onAdd,
    required Function(String) onDelete,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      if (isEditing)
        Row(children: [
          Expanded(
              child: TextField(
                  controller: itemController, decoration: const InputDecoration(hintText: "Enter value"))),
          IconButton(
              icon: const Icon(Icons.add),
              onPressed: () {
                final input = itemController.text.trim();
                if (input.isNotEmpty && !items.contains(input)) {
                  onAdd(input);
                  itemController.clear();
                }
              }),
        ]),
      if (items.isEmpty)
        const Text("None")
      else
        Column(
            children: items
                .map((val) => ListTile(
              title: Text(val),
              trailing: isEditing
                  ? IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => onDelete(val),
              )
                  : null,
            ))
                .toList()),
    ]);
  }

  void _showAddFacultyDialog(BuildContext context) {
    final _idController = TextEditingController();
    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    final _departmentController = TextEditingController();
    final _menteeController = TextEditingController();
    final _classController = TextEditingController();

    showDialog(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          elevation: 8,
          titlePadding: EdgeInsets.zero,
          title: _buildDialogHeader("Add New Faculty", () => Navigator.pop(context)),
          content: SingleChildScrollView(
            child: Column(children: [
              TextField(
                  controller: _idController,
                  decoration: const InputDecoration(labelText: 'Faculty ID')),
              TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email')),
              TextField(
                  controller: _departmentController,
                  decoration: const InputDecoration(labelText: 'Department')),
              TextField(
                  controller: _menteeController,
                  decoration: const InputDecoration(labelText: 'Mentees (comma separated IDs)')),
              TextField(
                  controller: _classController,
                  decoration: const InputDecoration(labelText: 'Classes (comma separated)')),
            ]),
          ),
          actions: [
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7F50),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10))),
                child: const Text('Add'),
                onPressed: () async {
                  final id = _idController.text.trim();
                  final name = _nameController.text.trim();
                  if (id.isEmpty || name.isEmpty) return;

                  final email = _emailController.text.trim();
                  final dept = _departmentController.text.trim();
                  final mentees = _menteeController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                  final classes = _classController.text
                      .split(',')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

                  await FirebaseFirestore.instance
                      .collection("colleges")
                      .doc("faculties")
                      .collection("all_faculties")
                      .doc(id)
                      .set({
                    "id": id,
                    "name": name,
                    "email": email,
                    "department": dept,
                    "mentees": mentees,
                    "classes": classes,
                  });
                  Navigator.pop(context);
                  setState(() {});
                }),
          ],
        ));
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
                onPressed: () => Navigator.pop(context)),
            title: const Text("FACULTY CONTROL",
                style: TextStyle(color: Colors.white)),
            centerTitle: true,
            actions: [
              IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {})
            ]),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by ID or Name',
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
              onPressed: () => _showAddFacultyDialog(context),
            ),
          ]),
        ),
        Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF2D2F38),
          child: const Text(
            "FACULTY INFORMATION",
            style: TextStyle(color: Colors.white),
          ),
        ),
        Container(
          color: Colors.black12,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
              Expanded(flex: 2, child: Text("FACULTY ID")),
              Expanded(flex: 3, child: Text("NAME")),
              Expanded(flex: 1, child: Text("DETAILS")),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredFaculties.length,
            itemBuilder: (context, index) {
              final faculty = _filteredFaculties[index];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFFF7F50), width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: Text(faculty['id'] ?? '')),
                    Expanded(flex: 3, child: Text(faculty['name'] ?? '')),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: ElevatedButton(
                          onPressed: () {
                            _showFacultyDetailsPopup(faculty, faculty['id']);
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
      ]),
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