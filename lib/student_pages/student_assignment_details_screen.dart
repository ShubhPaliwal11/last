import 'package:flutter/material.dart';

class AssignmentDetailsScreen extends StatelessWidget {
  final String assignmentTitle;
  final String dueDate;

  AssignmentDetailsScreen({required this.assignmentTitle, required this.dueDate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Assignment: $assignmentTitle"), backgroundColor: Colors.deepOrange),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Due Date: $dueDate", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.lightBlueAccent,
                    child: InkWell(
                      onTap: () {
                        // Handle upload assignment action
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(Icons.upload_file, size: 40, color: Colors.white),
                            SizedBox(height: 10),
                            Text("Upload Assignment", style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Card(
                    color: Colors.green,
                    child: InkWell(
                      onTap: () {
                        // Handle check report action
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            Icon(Icons.report, size: 40, color: Colors.white),
                            SizedBox(height: 10),
                            Text("Check Report", style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
