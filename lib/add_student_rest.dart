import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final projectId = "cams-f36be";
  final studentId = "S001";
  final collectionPath = "colleges/students/all_students";
  
  final url = Uri.parse("https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collectionPath/$studentId");

  print("Writing student data to Firestore REST API for project cams-f36be...");
  
  final data = {
    "fields": {
      "id": {"stringValue": studentId},
      "name": {"stringValue": "Jane Doe"},
      "email": {"stringValue": "jane.doe@example.com"},
      "department": {"stringValue": "CSE"},
      "class": {"stringValue": "CSE-A"},
      "mentor_id": {"stringValue": "F001"},
      "password": {"stringValue": "student123"}
    }
  };

  try {
    final response = await http.patch(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      print("Successfully added student login to Firestore database!");
    } else {
      print("Failed to add student: ${response.statusCode}");
      print(response.body);
    }
  } catch (e) {
    print("Error: $e");
  }
}
