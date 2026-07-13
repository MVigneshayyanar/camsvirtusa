import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> addStudent(String studentId, String name, String email, String className, String mentorId, String password) async {
  final projectId = "cams-f36be";
  final collectionPath = "colleges/students/all_students";
  final url = Uri.parse("https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collectionPath/$studentId");

  print("Writing $name data to Firestore...");
  
  final data = {
    "fields": {
      "id": {"stringValue": studentId},
      "name": {"stringValue": name},
      "email": {"stringValue": email},
      "department": {"stringValue": "CSE"},
      "class": {"stringValue": className},
      "mentor_id": {"stringValue": mentorId},
      "password": {"stringValue": password}
    }
  };

  try {
    final response = await http.patch(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      print("Successfully added student $studentId to Firestore database!");
    } else {
      print("Failed to add student $studentId: ${response.statusCode}");
      print(response.body);
    }
  } catch (e) {
    print("Error adding student $studentId: $e");
  }
}

void main() async {
  await addStudent("S002", "Alex Smith", "alex.smith@example.com", "CSE-A", "F001", "student123");
  await addStudent("S003", "Emily Brown", "emily.brown@example.com", "CSE-B", "F001", "student123");
}
