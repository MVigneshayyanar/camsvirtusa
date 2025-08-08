import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'classesList.dart';
import 'adminDashboard.dart';

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

  void _showAddDepartmentPopup() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: EdgeInsets.zero,
            title: _buildDialogHeader("Add Department", () => Navigator.pop(context)),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: _deptIdController, decoration: const InputDecoration(labelText: 'Department ID')),
                  TextField(controller: _deptNameController, decoration: const InputDecoration(labelText: 'Department Name')),
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
                    children: _classes.map((cls) {
                      return Chip(
                        label: Text(cls),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: () => setState(() => _classes.remove(cls)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  _deptIdController.clear();
                  _deptNameController.clear();
                  _classController.clear();
                  _classes.clear();
                  Navigator.pop(context);
                },
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: EdgeInsets.zero,
          title: _buildDialogHeader("Edit Classes", () => Navigator.pop(context)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...updatedClasses.map((cls) => ListTile(
                title: Text(cls),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    setState(() => updatedClasses.remove(cls));
                  },
                ),
              )),
              TextField(
                controller: classController,
                decoration: const InputDecoration(labelText: 'Add new class'),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    setState(() {
                      updatedClasses.add(value.trim());
                      classController.clear();
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
                await departmentsRef.doc(deptId).update({'classes': updatedClasses});
                Navigator.pop(context);
                setState(() {});
              },
              child: const Text("Save"),
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
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: AppBar(
          backgroundColor: const Color(0xFFFF7F50),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text("DEPARTMENT CONTROL", style: TextStyle(color: Colors.white)),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.notifications, color: Colors.white), onPressed: () {}),
          ],
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
                    onChanged: (val) => setState(() => _searchText = val),
                    decoration: InputDecoration(
                      hintText: 'Search by ID or Name',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(40)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.add_circle, size: 32, color: Color(0xFFFF7F50)),
                  onPressed: _showAddDepartmentPopup,
                ),
              ],
            ),
          ),

          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF2D2F38),
            child: const Text("DEPARTMENT INFORMATION", style: TextStyle(color: Colors.white)),
          ),

          Container(
            color: Colors.black12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Expanded(flex: 2, child: Text("DEPT ID")),
                Expanded(flex: 3, child: Text("NAME")),
                Expanded(flex: 1, child: Text("DETAILS")),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: departmentsRef.snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final id = data['id']?.toString().toLowerCase() ?? '';
                  final name = data['name']?.toString().toLowerCase() ?? '';
                  return id.contains(_searchText.toLowerCase()) ||
                      name.contains(_searchText.toLowerCase());
                }).toList();

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final data = filteredDocs[index].data() as Map<String, dynamic>;
                    final id = data['id'] ?? '';
                    final name = data['name'] ?? '';
                    final classes = List<String>.from(data['classes'] ?? []);

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.orange, width: 1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(id)),
                          Expanded(flex: 3, child: Text(name)),
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClassesListPage(departmentId: id),
                                    ),
                                  );
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
            IconButton(icon: Image.asset("assets/search.png", height: 26), onPressed: () {}),
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
            IconButton(icon: Image.asset("assets/account.png", height: 26), onPressed: () {}),
          ],
        ),
      ),
    );
  }
}
