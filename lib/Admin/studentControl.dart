import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentControlPage extends StatefulWidget {
  const StudentControlPage({Key? key}) : super(key: key);

  @override
  State<StudentControlPage> createState() => _StudentControlPageState();
}

class _StudentControlPageState extends State<StudentControlPage> {
  Future<List<Map<String, dynamic>>> _fetchStudents() async {
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

    final mentorMap = {
      for (var doc in facultySnapshot.docs) doc.id: doc['name']
    };

    return studentSnapshot.docs.map((doc) {
      final data = doc.data();
      data['docId'] = doc.id;
      data['mentor_name'] = mentorMap[data['mentor_id']] ?? 'Unknown';
      return data;
    }).toList();
  }

  void _showStudentPopup(Map<String, dynamic> student, String docId) async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection("colleges")
        .doc("students")
        .collection("all_students")
        .doc(docId)
        .get();

    final data = docSnapshot.data();
    if (data == null) return;

    final nameController = TextEditingController(text: data['name']);
    final emailController = TextEditingController(text: data['email']);
    final deptController = TextEditingController(text: data['department']);
    final passwordController =
    TextEditingController(text: data['password'] ?? '');
    final mentorIdController = TextEditingController(text: data['mentor_id']);
    final classController = TextEditingController(text: data['class']);

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
                        decoration: const InputDecoration(labelText: "Name"))
                        : Text("Name: ${data['name'] ?? ''}"),
                    isEditing
                        ? TextField(
                        controller: emailController,
                        decoration:
                        const InputDecoration(labelText: "Email"))
                        : Text("Email: ${data['email'] ?? ''}"),
                    isEditing
                        ? TextField(
                        controller: deptController,
                        decoration:
                        const InputDecoration(labelText: "Department"))
                        : Text("Department: ${data['department'] ?? ''}"),
                    isEditing
                        ? TextField(
                        controller: mentorIdController,
                        decoration:
                        const InputDecoration(labelText: "Mentor ID"))
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Mentor ID: ${data['mentor_id'] ?? ''}"),
                        Text(
                            "Mentor Name: ${student['mentor_name'] ?? 'Unknown'}"),
                      ],
                    ),
                    isEditing
                        ? TextField(
                        controller: classController,
                        decoration:
                        const InputDecoration(labelText: "Class"))
                        : Text("Class: ${data['class'] ?? ''}"),
                    isEditing
                        ? TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration:
                      const InputDecoration(labelText: "Password"),
                    )
                        : const Text("Password: ••••••••"),
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
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection("colleges")
                              .doc("students")
                              .collection("all_students")
                              .doc(docId)
                              .delete();
                          Navigator.pop(context);
                          setState(() {});
                        },
                      ),
                      const Spacer(),
                      TextButton(
                        child: const Text('Save'),
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
                            "mentor_id": mentorIdController.text.trim(),
                            "class": classController.text.trim(),
                            "password": passwordController.text.trim(),
                          });

                          Navigator.pop(context);
                          setState(() {});
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

  void _showAddStudentDialog(BuildContext context) {
    final _idController = TextEditingController();
    final _nameController = TextEditingController();
    final _emailController = TextEditingController();
    final _deptController = TextEditingController();
    final _mentorController = TextEditingController();
    final _classController = TextEditingController();
    final _passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add New Student'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                  controller: _idController,
                  decoration:
                  const InputDecoration(labelText: 'Student ID')),
              TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name')),
              TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email')),
              TextField(
                  controller: _deptController,
                  decoration: const InputDecoration(labelText: 'Department')),
              TextField(
                  controller: _mentorController,
                  decoration: const InputDecoration(labelText: 'Mentor ID')),
              TextField(
                  controller: _classController,
                  decoration: const InputDecoration(labelText: 'Class')),
              TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password')),
            ],
          ),
        ),
        actions: [
          TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(context)),
          ElevatedButton(
            child: const Text('Add'),
            onPressed: () async {
              final id = _idController.text.trim();
              final name = _nameController.text.trim();
              final email = _emailController.text.trim();
              final dept = _deptController.text.trim();
              final mentor = _mentorController.text.trim();
              final studentClass = _classController.text.trim();
              final password = _passwordController.text.trim();

              if (id.isEmpty || name.isEmpty) return;

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
                "mentor_id": mentor,
                "class": studentClass,
                "password": password,
              });

              final mentorRef = FirebaseFirestore.instance
                  .collection("colleges")
                  .doc("faculties")
                  .collection("all_faculties")
                  .doc(mentor);

              final mentorDoc = await mentorRef.get();

              if (mentorDoc.exists) {
                final currentMentees =
                List<String>.from(mentorDoc.data()?['mentees'] ?? []);
                if (!currentMentees.contains(id)) {
                  currentMentees.add(id);
                  await mentorRef.update({'mentees': currentMentees});
                }
              }

              Navigator.pop(context);
              setState(() {});
            },
          ),
        ],
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
          title: const Text("STUDENT CONTROL",
              style: TextStyle(color: Colors.white)),
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
                    decoration: InputDecoration(
                      hintText: 'Search',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(40)),
                      contentPadding:
                      const EdgeInsets.symmetric(vertical: 5),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.add_circle,
                      size: 32, color: Color(0xFFFF7F50)),
                  onPressed: () => _showAddStudentDialog(context),
                ),
              ],
            ),
          ),
          Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF2D2F38),
            child: const Text("STUDENT INFORMATION",
                style: TextStyle(color: Colors.white)),
          ),
          Container(
            color: Colors.black12,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: const [
                Expanded(flex: 2, child: Text("STUDENT ID")),
                Expanded(flex: 3, child: Text("NAME")),
                Expanded(flex: 1, child: Text("DETAILS")),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchStudents(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("No student data available."));
                }

                final studentList = snapshot.data!;
                return ListView.builder(
                  itemCount: studentList.length,
                  itemBuilder: (context, index) {
                    final student = studentList[index];
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: const BoxDecoration(
                        border:
                        Border(bottom: BorderSide(color: Colors.orange)),
                      ),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(student['id'] ?? '')),
                          Expanded(flex: 3, child: Text(student['name'] ?? '')),
                          Expanded(
                            flex: 1,
                            child: ElevatedButton(
                              onPressed: () =>
                                  _showStudentPopup(student, student['id']),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF7F50),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
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
