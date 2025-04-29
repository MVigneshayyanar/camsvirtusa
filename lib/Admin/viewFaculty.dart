import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ViewFacultyScreen extends StatefulWidget {
  const ViewFacultyScreen({Key? key}) : super(key: key);

  @override
  State<ViewFacultyScreen> createState() => _ViewFacultyScreenState();
}

class _ViewFacultyScreenState extends State<ViewFacultyScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("VIEW FACULTIES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF2D336B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: const Color(0xFF76C7C0),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchField(),
            const SizedBox(height: 10),
            Expanded(child: _buildFacultyList()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value.trim().toLowerCase()),
      decoration: InputDecoration(
        labelText: "Search by Name or ID",
        prefixIcon: const Icon(Icons.search),
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildFacultyList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('faculties').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("No faculty records found"));

        var filtered = snapshot.data!.docs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          String name = data['name'].toString().toLowerCase();
          String id = data['facultyId'].toString().toLowerCase();
          return name.contains(_searchQuery) || id.contains(_searchQuery);
        }).toList();

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            var faculty = filtered[index].data() as Map<String, dynamic>;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              child: ListTile(
                title: Text(faculty['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Dept: ${faculty['department']} | ID: ${faculty['facultyId']}"),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () => _showDetails(faculty),
              ),
            );
          },
        );
      },
    );
  }

  void _showDetails(Map<String, dynamic> faculty) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Faculty Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _infoRow("Name", faculty['name']),
            _infoRow("ID", faculty['facultyId']),
            _infoRow("Dept", faculty['department']),
            _infoRow("Phone", faculty['phone']),
            _infoRow("Email", faculty['email']),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
