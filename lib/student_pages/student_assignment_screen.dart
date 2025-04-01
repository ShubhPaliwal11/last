import 'package:flutter/material.dart';
import 'student_assignment_details_screen.dart'; // Import the assignment details screen

class AssignmentScreen extends StatelessWidget {
  final String className;

  AssignmentScreen({required this.className});

  final List<Map<String, String>> assignments = [
    {"title": "Algebra Homework", "dueDate": "Feb 5"},
    {"title": "Science Lab Report", "dueDate": "Feb 10"},
    {"title": "History Essay", "dueDate": "Feb 12"},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("$className - Assignments"), backgroundColor: Colors.teal),
      body: ListView.builder(
        itemCount: assignments.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(assignments[index]["title"]!),
            subtitle: Text("Due: ${assignments[index]["dueDate"]}"),
            trailing: Icon(Icons.arrow_forward),
            onTap: () {
              // Navigate to Assignment Details Screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AssignmentDetailsScreen(
                    assignmentTitle: assignments[index]["title"]!,
                    dueDate: assignments[index]["dueDate"]!,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}