import 'package:flutter/material.dart';
import 'student_assignment_screen.dart'; // Import the assignment screen

class ClassesScreen extends StatelessWidget {
  final List<String> classList = [
    "Mathematics",
    "Science",
    "History",
    "English",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Select Your Class"),
        backgroundColor: Colors.blue,
      ),

      body: ListView.builder(
        itemCount: classList.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(classList[index]),
            trailing: Icon(Icons.arrow_forward),
            onTap: () {
              // Navigate to the Assignment Screen with class name
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) =>
                      AssignmentScreen(className: classList[index]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
