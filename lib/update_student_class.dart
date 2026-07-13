import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> changeClass(String studentId, String className) async {
  final projectId = "cams-f36be";
  final collectionPath = "colleges/students/all_students";
  final url = Uri.parse("https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collectionPath/$studentId?updateMask.fieldPaths=class");

  print("Updating class to '$className' for student $studentId...");
  
  final data = {
    "fields": {
      "class": {"stringValue": className}
    }
  };

  try {
    final response = await http.patch(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      print("Successfully updated class for student $studentId!");
    } else {
      print("Failed to update student $studentId: ${response.statusCode}");
      print(response.body);
    }
  } catch (e) {
    print("Error updating student $studentId: $e");
  }
}

void main() async {
  // Update S003 (Emily Brown) class to CSE-A (previously CSE-B)
  await changeClass("S003", "CSE-A");
}
