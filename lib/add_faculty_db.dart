import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  print("Initializing Firebase...");
  await Firebase.initializeApp();
  print("Firebase Initialized!");

  final facultyId = "F001";
  final facultyData = {
    "id": facultyId,
    "name": "Dr. John Doe",
    "email": "john.doe@example.com",
    "department": "CSE",
    "password": "faculty123",
    "classes": ["CSE-A", "CSE-B"],
    "mentees": []
  };

  print("Writing faculty data to Firestore...");
  await FirebaseFirestore.instance
      .collection('colleges')
      .doc('faculties')
      .collection('all_faculties')
      .doc(facultyId)
      .set(facultyData);

  print("Successfully added faculty login to Firestore database!");
}
