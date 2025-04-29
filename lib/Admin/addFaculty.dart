import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddFacultyScreen extends StatefulWidget {
  const AddFacultyScreen({Key? key}) : super(key: key);

  @override
  State<AddFacultyScreen> createState() => _AddFacultyScreenState();
}

class _AddFacultyScreenState extends State<AddFacultyScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isSaving = false;

  Future<void> _saveFaculty() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      final facultyId = _idController.text.trim();

      try {
        await FirebaseFirestore.instance
            .collection('faculties')
            .doc(facultyId)
            .set({
          'name': _nameController.text.trim(),
          'facultyId': facultyId,
          'department': _departmentController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text.trim(), // 🔐
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Faculty added successfully!')),
        );

        _nameController.clear();
        _idController.clear();
        _departmentController.clear();
        _emailController.clear();
        _phoneController.clear();
        _passwordController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      } finally {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("ADD FACULTY"),
        backgroundColor: const Color(0xFF2A7F77),
      ),
      body: Container(
        color: const Color(0xFF76C7C0),
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(_nameController, "Full Name"),
              _buildTextField(_idController, "Faculty ID"),
              _buildTextField(_departmentController, "Department"),
              _buildTextField(_emailController, "Email", inputType: TextInputType.emailAddress),
              _buildTextField(_phoneController, "Phone", inputType: TextInputType.phone),
              _buildTextField(_passwordController, "Password", isPassword: true),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveFaculty,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A7F77)),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SAVE FACULTY", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType inputType = TextInputType.text, bool isPassword = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: inputType,
        validator: (value) => value == null || value.isEmpty ? "Please enter $label" : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
