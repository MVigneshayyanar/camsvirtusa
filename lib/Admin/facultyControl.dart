import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FacultyOverviewPage extends StatefulWidget {
  const FacultyOverviewPage({Key? key}) : super(key: key);

  @override
  State<FacultyOverviewPage> createState() => _FacultyOverviewPageState();
}

class _FacultyOverviewPageState extends State<FacultyOverviewPage> {
  Future<List<Map<String, dynamic>>> _fetchFaculties() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("colleges")
        .doc("faculties")
        .collection("all_faculties")
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
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

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey("name")) {
          menteeMap[id] = data["name"];
        }
      }
    }

    return menteeMap;
  }

  void _showFacultyDetailsPopup(BuildContext context, String docId) async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection("colleges")
        .doc("faculties")
        .collection("all_faculties")
        .doc(docId)
        .get();

    final data = docSnapshot.data();
    if (data == null) return;

    final nameController = TextEditingController(text: data['name']);
    final emailController = TextEditingController(text: data['email']);
    final deptController = TextEditingController(text: data['department']);

    List<String> menteeIds = List<String>.from(data['mentees'] ?? []);
    List<String> classes = List<String>.from(data['classes'] ?? []);

    final menteeController = TextEditingController();
    final classController = TextEditingController();

    Map<String, String> mentees = await _fetchStudentNames(menteeIds);

    bool isEditing = false;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("ID: ${data['id'] ?? ''}"),
                    const SizedBox(height: 10),
                    isEditing
                        ? TextField(
                      controller: nameController,
                      decoration:
                      const InputDecoration(labelText: "Name"),
                    )
                        : Text("Name: ${data['name'] ?? ''}"),
                    isEditing
                        ? TextField(
                      controller: emailController,
                      decoration:
                      const InputDecoration(labelText: "Email"),
                    )
                        : Text("Email: ${data['email'] ?? ''}"),
                    isEditing
                        ? TextField(
                      controller: deptController,
                      decoration:
                      const InputDecoration(labelText: "Department"),
                    )
                        : Text("Department: ${data['department'] ?? ''}"),
                    const SizedBox(height: 10),
                    const Text("Mentees:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    if (isEditing)
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: menteeController,
                                  decoration: const InputDecoration(
                                      hintText: "Add mentee ID"),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () async {
                                  final id = menteeController.text.trim();
                                  if (id.isNotEmpty && !mentees.containsKey(id)) {
                                    final nameMap =
                                    await _fetchStudentNames([id]);
                                    if (nameMap.containsKey(id)) {
                                      setState(() {
                                        mentees[id] = nameMap[id]!;
                                        menteeController.clear();
                                      });
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          ...mentees.entries.map((entry) => ListTile(
                            title: Text("${entry.value} (${entry.key})"),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  mentees.remove(entry.key);
                                });
                              },
                            ),
                          )),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: mentees.isEmpty
                            ? [const Text("None")]
                            : mentees.entries
                            .map((e) => Text("• ${e.value} (${e.key})"))
                            .toList(),
                      ),
                    const SizedBox(height: 10),
                    const Text("Classes:",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    if (isEditing)
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: classController,
                                  decoration: const InputDecoration(
                                      hintText: "Add class"),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  final className =
                                  classController.text.trim();
                                  if (className.isNotEmpty &&
                                      !classes.contains(className)) {
                                    setState(() {
                                      classes.add(className);
                                      classController.clear();
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                          ...classes.map((c) => ListTile(
                            title: Text(c),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () {
                                setState(() {
                                  classes.remove(c);
                                });
                              },
                            ),
                          )),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: classes.isEmpty
                            ? [const Text("None")]
                            : classes.map((e) => Text("• $e")).toList(),
                      ),
                  ],
                ),
              ),
              actions: [
                if (!isEditing)
                  TextButton(
                    child: const Text('Edit'),
                    onPressed: () {
                      setState(() => isEditing = true);
                    },
                  ),
                if (isEditing)
                  Row(
                    children: [
                      TextButton(
                        child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text("Confirm Delete"),
                              content: const Text("Are you sure you want to delete this faculty? This action cannot be undone."),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Cancel"),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text("Delete"),
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

                            Navigator.pop(context); // Close the main popup
                            setState(() {}); // Refresh UI
                          }
                        },
                      ),
                      const Spacer(),
                      TextButton(
                        child: const Text('Save'),
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
                            "mentees": mentees.keys.toList(),
                            "classes": classes,
                          });

                          Navigator.pop(context);
                          setState(() {}); // refresh
                        },
                      ),
                    ],
                  ),
                TextButton(
                  child: const Text('Close'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],


            );
          },
        );
      },
    );
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
        title: const Text('Add New Faculty'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: _idController,
                decoration: const InputDecoration(labelText: 'Faculty ID'),
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
                controller: _menteeController,
                decoration: const InputDecoration(
                  labelText: 'Mentees (comma separated IDs)',
                ),
              ),
              TextField(
                controller: _classController,
                decoration: const InputDecoration(
                  labelText: 'Classes (comma separated)',
                ),
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
            child: const Text('Add'),
            onPressed: () async {
              final id = _idController.text.trim();
              final name = _nameController.text.trim();
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

              if (id.isEmpty || name.isEmpty) return;

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
              setState(() {}); // Refresh the list
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Unchanged UI code omitted for brevity
    // You can paste your original Scaffold build code here
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
            title: const Text(
              "FACULTY CONTROL",
              style: TextStyle(color: Colors.white),
            ),
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
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search',
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
                    icon: const Icon(Icons.add_circle,
                        size: 32, color: Color(0xFFFF7F50)),
                    onPressed: () => _showAddFacultyDialog(context),
                  ),
                ],
              ),
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
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchFaculties(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No faculty data available."));
                  }

                  final facultyList = snapshot.data!;
                  return ListView.builder(
                    itemCount: facultyList.length,
                    itemBuilder: (context, index) {
                      final faculty = facultyList[index];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.orange, width: 1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Text(faculty['id'] ?? '')),
                            Expanded(flex: 3, child: Text(faculty['name'] ?? '')),
                            Expanded(
                              flex: 1,
                              child: ElevatedButton(
                                onPressed: () {
                                  _showFacultyDetailsPopup(
                                      context, faculty['id'] ?? '');
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFF7F50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text("View"),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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
