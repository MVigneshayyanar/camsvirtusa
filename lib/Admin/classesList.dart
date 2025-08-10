import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'classStudents.dart';
import 'adminDashboard.dart';

class ClassesListPage extends StatefulWidget {
  final String departmentId;

  const ClassesListPage({Key? key, required this.departmentId}) : super(key: key);

  @override
  State<ClassesListPage> createState() => _ClassesListPageState();
}

class _ClassesListPageState extends State<ClassesListPage> {
  List<String> allClasses = [];
  List<String> filteredClasses = [];
  bool isLoading = true;

  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _addClassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchClasses();

    _searchController.addListener(() {
      filterClasses(_searchController.text);
    });
  }

  Future<void> fetchClasses() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('colleges')
          .doc('departments')
          .collection('all_departments')
          .doc(widget.departmentId)
          .get();

      final List<dynamic> classArray = snapshot.data()?['classes'] ?? [];

      setState(() {
        allClasses = classArray.cast<String>();
        filteredClasses = List.from(allClasses);
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching classes: $e');
      setState(() => isLoading = false);
    }
  }

  void filterClasses(String query) {
    final lowerQuery = query.toLowerCase();
    final filtered = allClasses.where((c) => c.toLowerCase().contains(lowerQuery)).toList();

    setState(() {
      filteredClasses = filtered;
    });
  }

  void _showAddClassDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add New Class"),
          content: TextField(
            controller: _addClassController,
            decoration: const InputDecoration(hintText: "Enter class name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _addClassController.clear();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: _addClassToFirestore,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7F50),
                foregroundColor: Colors.white,
              ),
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addClassToFirestore() async {
    final newClass = _addClassController.text.trim();
    if (newClass.isEmpty) return;

    Navigator.pop(context); // Close the dialog

    final docRef = FirebaseFirestore.instance
        .collection('colleges')
        .doc('departments')
        .collection('all_departments')
        .doc(widget.departmentId);

    try {
      await docRef.update({
        'classes': FieldValue.arrayUnion([newClass]),
      });

      setState(() {
        allClasses.add(newClass);
        filteredClasses.add(newClass);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Class added successfully")),
      );

      _addClassController.clear();
    } catch (e) {
      debugPrint("Error adding class: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add class")),
      );
    }
  }

  void _openStudents(String className) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClassStudentsPage(
          departmentId: widget.departmentId,
          className: className,
        ),
      ),
    );
  }

  void _refreshData() {
    setState(() {
      isLoading = true;
      _searchController.clear();
      allClasses.clear();
      filteredClasses.clear();
    });

    // Add a small delay to show the refresh is happening
    Future.delayed(const Duration(milliseconds: 100), () {
      fetchClasses();
    });
  }

  @override
  Widget build(BuildContext context) {
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
            "CLASSES",
            style: TextStyle(color: Colors.white),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _refreshData,
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search class name',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(40)),
                        contentPadding: const EdgeInsets.symmetric(vertical: 5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Color(0xFFFF7F50), size: 32),
                    onPressed: _showAddClassDialog,
                  ),
                ],
              ),
            ),
            Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFF2D2F38),
              child: const Text(
                "CLASS LIST",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredClasses.isEmpty
                  ? const Center(child: Text("No classes found."))
                  : ListView.builder(
                padding: EdgeInsets.only(
                  bottom: 90 + MediaQuery.of(context).padding.bottom, // Add padding for bottom nav
                ),
                itemCount: filteredClasses.length,
                itemBuilder: (context, index) {
                  final className = filteredClasses[index];
                  return GestureDetector(
                    onTap: () => _openStudents(className),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.orange, width: 1),
                        ),
                      ),
                      child: Text(
                        className,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        height: 70 + MediaQuery.of(context).padding.bottom,
        decoration: const BoxDecoration(
          color: Color(0xFFE5E5E5),
          borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
        ),
        child: SafeArea(
          minimum: EdgeInsets.zero,
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
      ),
    );
  }
}