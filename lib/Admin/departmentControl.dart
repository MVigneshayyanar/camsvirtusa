import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'classStudent.dart';// ake sure this exists and is implemented

class DepartmentControlPage extends StatefulWidget {
  const DepartmentControlPage({super.key});

  @override
  State<DepartmentControlPage> createState() => _DepartmentControlPageState();
}

class _DepartmentControlPageState extends State<DepartmentControlPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _deptIdController = TextEditingController();
  final TextEditingController _deptNameController = TextEditingController();
  final TextEditingController _classController = TextEditingController();

  List<String> _classes = [];
  String _searchText = '';

  final CollectionReference departmentsRef = FirebaseFirestore.instance
      .collection('colleges')
      .doc('departments')
      .collection('all_departments');

  void _showAddDepartmentPopup() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text("Add Department"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _deptIdController,
                    decoration: const InputDecoration(labelText: 'Department ID'),
                  ),
                  TextField(
                    controller: _deptNameController,
                    decoration: const InputDecoration(labelText: 'Department Name'),
                  ),
                  TextField(
                    controller: _classController,
                    decoration: const InputDecoration(labelText: 'Add Class'),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        setState(() {
                          _classes.add(value.trim());
                          _classController.clear();
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8.0,
                    children: _classes
                        .map((cls) => Chip(
                      label: Text(cls),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () {
                        setState(() {
                          _classes.remove(cls);
                        });
                      },
                    ))
                        .toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.pop(context),
              ),
              ElevatedButton(
                child: const Text('Save'),
                onPressed: () async {
                  final id = _deptIdController.text.trim();
                  final name = _deptNameController.text.trim();
                  if (id.isEmpty || name.isEmpty) return;

                  await departmentsRef.doc(id).set({
                    'id': id,
                    'name': name,
                    'classes': _classes,
                  });

                  _deptIdController.clear();
                  _deptNameController.clear();
                  _classController.clear();
                  _classes.clear();

                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditClassesDialog(String deptId, List<String> existingClasses) {
    final TextEditingController classController = TextEditingController();
    List<String> updatedClasses = List.from(existingClasses);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Edit Classes"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...updatedClasses.map((cls) => ListTile(
                title: Text(cls),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClassStudentsPage(
                        departmentId: deptId,
                        className: cls,
                      ),
                    ),
                  );
                },
              )),
              TextField(
                controller: classController,
                decoration: const InputDecoration(labelText: 'Add new class'),
                onSubmitted: (value) async {
                  if (value.trim().isNotEmpty) {
                    setState(() {
                      updatedClasses.add(value.trim());
                      classController.clear();
                    });
                    await departmentsRef.doc(deptId).update({
                      'classes': updatedClasses,
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close"),
            ),
            ElevatedButton(
              onPressed: () async {
                await departmentsRef.doc(deptId).update({
                  'classes': updatedClasses,
                });
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  List<QueryDocumentSnapshot> _filterDepartments(QuerySnapshot snapshot) {
    return snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final id = data['id']?.toString().toLowerCase() ?? '';
      final name = data['name']?.toString().toLowerCase() ?? '';
      return id.contains(_searchText.toLowerCase()) ||
          name.contains(_searchText.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFFFD7E45),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.menu, color: Colors.white),
                const SizedBox(width: 12),
                const Text(
                  "FACULTY OVERVIEW",
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Icon(Icons.notifications, color: Colors.white),
              ],
            ),
          ),

          // Search + Add
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F1F1),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search',
                        border: InputBorder.none,
                        icon: Icon(Icons.search),
                      ),
                      onChanged: (val) => setState(() => _searchText = val),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _showAddDepartmentPopup,
                  icon: const Icon(Icons.add_circle, size: 32),
                ),
              ],
            ),
          ),

          // Department Label
          Container(
            alignment: Alignment.centerLeft,
            margin: const EdgeInsets.only(left: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFF3A3A3A),
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            child: const Text(
              "DEPARTMENTS",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFFF5F5F5),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("DEPT", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 5, child: Text("NAME", style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(child: Text("DETAILS", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // Department List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: departmentsRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = _filterDepartments(snapshot.data!);
                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = data['id'] ?? '';
                    final name = data['name'] ?? '';
                    final classes = List<String>.from(data['classes'] ?? []);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(id, style: const TextStyle(fontWeight: FontWeight.w600))),
                          Expanded(flex: 5, child: Text(name)),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _showEditClassesDialog(id, classes),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFD7E45),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                padding: const EdgeInsets.symmetric(vertical: 6),
                              ),
                              child: const Text("View", style: TextStyle(color: Colors.white)),
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

          // Bottom nav
          Container(
            height: 70,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
            ),
            child: const Center(child: Icon(Icons.home, color: Colors.orange, size: 36)),
          ),
        ],
      ),
    );
  }
}
