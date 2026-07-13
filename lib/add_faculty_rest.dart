import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // Correct project_id from google-services.json is "cams-f36be"
  final projectId = "cams-f36be";
  final collectionPath = "colleges/faculties/all_faculties";
  
  final facultyId = "F001";
  final url = Uri.parse("https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/$collectionPath/$facultyId");

  print("Writing faculty data to Firestore REST API for project cams-f36be...");
  
  final data = {
    "fields": {
      "id": {"stringValue": facultyId},
      "name": {"stringValue": "Dr. John Doe"},
      "email": {"stringValue": "john.doe@example.com"},
      "department": {"stringValue": "CSE"},
      "password": {"stringValue": "faculty123"},
      "classes": {
        "arrayValue": {
          "values": [
            {"stringValue": "CSE-A"},
            {"stringValue": "CSE-B"}
          ]
        }
      },
      "mentees": {
        "arrayValue": {
          "values": []
        }
      }
    }
  };

  try {
    final response = await http.patch(
      url,
      headers: {"Content-Type": "application/json"},
      body: json.encode(data),
    );

    if (response.statusCode == 200) {
      print("Successfully added faculty login to Firestore database!");
    } else {
      print("Failed to add faculty: ${response.statusCode}");
      print(response.body);
    }
  } catch (e) {
    print("Error: $e");
  }
}
