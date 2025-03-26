import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddStudentScreen extends StatefulWidget {
  @override
  _AddStudentScreenState createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _rollController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _batchController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();
  final TextEditingController _courseController = TextEditingController();

  Future<void> _addStudent() async {
    if (_formKey.currentState!.validate()) {
      await FirebaseFirestore.instance.collection('students').add({
        'name': _nameController.text,
        'id': _idController.text,
        'roll_number': _rollController.text,
        'email': _emailController.text,
        'department': _departmentController.text,
        'batch': _batchController.text,
        'section': _sectionController.text,
        'course_list': _courseController.text,
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Student Added Successfully!")));
      Navigator.pop(context); // Go back to the previous screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("ADD NEW STUDENT")),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _nameController, decoration: InputDecoration(labelText: "STUDENT NAME"), validator: (value) => value!.isEmpty ? "Required" : null),
              TextFormField(controller: _idController, decoration: InputDecoration(labelText: "STUDENT ID NUMBER"), validator: (value) => value!.isEmpty ? "Required" : null),
              TextFormField(controller: _rollController, decoration: InputDecoration(labelText: "STUDENT ROLL NUMBER"), validator: (value) => value!.isEmpty ? "Required" : null),
              TextFormField(controller: _emailController, decoration: InputDecoration(labelText: "COLLEGE MAIL"), validator: (value) => value!.isEmpty ? "Required" : null),
              TextFormField(controller: _departmentController, decoration: InputDecoration(labelText: "DEPARTMENT"), validator: (value) => value!.isEmpty ? "Required" : null),
              TextFormField(controller: _batchController, decoration: InputDecoration(labelText: "BATCH"), validator: (value) => value!.isEmpty ? "Required" : null),
              TextFormField(controller: _sectionController, decoration: InputDecoration(labelText: "SECTION"), validator: (value) => value!.isEmpty ? "Required" : null),
              TextFormField(controller: _courseController, decoration: InputDecoration(labelText: "COURSE LIST"), validator: (value) => value!.isEmpty ? "Required" : null),
              SizedBox(height: 20),
              ElevatedButton(onPressed: _addStudent, child: Text("ADD STUDENT")),
            ],
          ),
        ),
      ),
    );
  }
}
