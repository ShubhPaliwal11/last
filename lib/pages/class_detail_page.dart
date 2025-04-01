import 'package:flutter/material.dart';
import '../models/class_model.dart';
import '../models/assignment_model.dart';
import '../services/assignment_service.dart';
import '../services/submission_service.dart';
import '../utils/supabase_config.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:developer' as developer;

class ClassDetailPage extends StatefulWidget {
  final ClassModel classModel;

  ClassDetailPage({required this.classModel});

  @override
  _ClassDetailPageState createState() => _ClassDetailPageState();
}

class _ClassDetailPageState extends State<ClassDetailPage> {
  bool _isLoading = true;
  List<AssignmentModel> _assignments = [];
  Map<String, bool> _submittedAssignments = {};
  Map<String, String> _submissionIds = {}; // Store submission IDs

  @override
  void initState() {
    super.initState();
    _loadAssignments();
  }

  Future<void> _loadAssignments() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get all assignments for this class
      final assignments = await AssignmentService.getClassAssignments(widget.classModel.id);
      
      // Check which assignments the student has already submitted
      final user = await supabase.auth.currentUser;
      
      if (user != null) {
        Map<String, bool> submittedMap = {};
        Map<String, String> submissionIdMap = {};
        
        for (var assignment in assignments) {
          final submission = await SubmissionService.getSubmission(
            assignment.id, 
            user.id
          );
          submittedMap[assignment.id] = submission != null;
          
          // Store submission ID for later use
          if (submission != null) {
            submissionIdMap[assignment.id] = submission.id;
          }
        }
        
        setState(() {
          _assignments = assignments;
          _submittedAssignments = submittedMap;
          _submissionIds = submissionIdMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading assignments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _submitAssignment(AssignmentModel assignment) async {
    String? uploadedFileUrl;
    String? uploadedFileName;
    String? comment;
    
    final TextEditingController commentController = TextEditingController();
    
    // Function to upload file to Supabase storage
    Future<String?> _uploadFile() async {
      try {
        setState(() {
          _isLoading = true;
        });
        
        print('Starting submission file upload process');
        
        // Get current user ID
        final user = await supabase.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }
        
        // Use our dedicated submission file upload method
        final fileUrl = await SubmissionService.uploadSubmissionFile(user.id, assignment.id);
        
        if (fileUrl == null) {
          throw Exception('Failed to upload submission file');
        }
        
        print('Submission file uploaded successfully: $fileUrl');
        
        // Update the file name for display (extract from URL)
        final fileName = fileUrl.split('/').last;
        uploadedFileName = fileName;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('File uploaded successfully')),
        );
        
        return fileUrl;
      } catch (e) {
        print('Error uploading submission file: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
        return null;
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
    
    // Show submission dialog
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Submit Assignment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Due: ${DateFormat('MMM d, yyyy').format(assignment.dueDate)}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    SizedBox(height: 16),
                    
                    // Comment field
                    TextField(
                      controller: commentController,
                      decoration: InputDecoration(
                        labelText: 'Comment (Optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    SizedBox(height: 16),
                    
                    // File upload
                    if (uploadedFileUrl == null)
                      ElevatedButton.icon(
                        icon: Icon(Icons.upload_file),
                        label: Text('Upload Submission'),
                        onPressed: () async {
                          final url = await _uploadFile();
                          if (url != null) {
                            uploadedFileUrl = url;
                            setState(() {});
                          }
                        },
                      )
                    else
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'File uploaded: ${uploadedFileName ?? "file"}',
                                style: TextStyle(
                                  color: Colors.green[800],
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 16),
                              onPressed: () {
                                setState(() {
                                  uploadedFileUrl = null;
                                  uploadedFileName = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    comment = commentController.text.trim();
                    Navigator.pop(context, true);
                  },
                  child: Text('Submit'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) async {
      if (result == true) {
        setState(() {
          _isLoading = true;
        });
        
        try {
          final user = await supabase.auth.currentUser;
          
          if (user != null) {
            if (uploadedFileUrl == null && comment?.isEmpty != false) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please upload a file or add a comment')),
              );
              setState(() {
                _isLoading = false;
              });
              return;
            }
            
            await SubmissionService.submitAssignment(
              assignmentId: assignment.id,
              studentId: user.id,
              fileUrl: uploadedFileUrl,
              comment: comment,
            );
            
            // Refresh assignments
            await _loadAssignments();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Assignment submitted successfully!')),
            );
          }
        } catch (e) {
          developer.log('Error submitting assignment: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error submitting assignment: ${e.toString()}')),
          );
          setState(() {
            _isLoading = false;
          });
        }
      }
    });
  }

  // Function to safely open URLs
  Future<void> _openUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No file URL available')),
      );
      return;
    }

    try {
      // Debug the URL
      developer.log('Attempting to open URL: $urlString');
      
      // Try to fix common issues with the URL format
      String fixedUrl = urlString;
      
      // If URL doesn't start with http or https, assume it's a relative path in Supabase storage
      if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
        // Construct a proper URL using the storage endpoint and bucket
        final supabaseUrl = 'https://shrnxdbbaxfhjaxelbjl.supabase.co';
        fixedUrl = '$supabaseUrl/storage/v1/object/public/assignments/$urlString';
        developer.log('Fixed relative URL to: $fixedUrl');
      }
      
      // Create a Uri object
      final Uri url = Uri.parse(fixedUrl);
      
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Opening file...')),
      );
      
      // Try to launch the URL
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        developer.log('Cannot launch URL directly: $fixedUrl');
        
        // As a fallback, try opening in browser with _blank target
        final browserUrl = Uri.parse('https://shrnxdbbaxfhjaxelbjl.supabase.co/storage/v1/object/public/assignments/${Uri.encodeComponent(urlString)}');
        if (await canLaunchUrl(browserUrl)) {
          await launchUrl(browserUrl, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open file. Try downloading it manually.')),
          );
        }
      }
    } catch (e) {
      developer.log('Error parsing or opening URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: ${e.toString()}')),
      );
    }
  }

  // Add a method to show feedback
  Future<void> _showFeedback(String assignmentId) async {
    String? submissionId = _submissionIds[assignmentId];
    if (submissionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No submission found for this assignment')),
      );
      return;
    }
    
    print('Attempting to show feedback for submission: $submissionId');
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator()),
    );
    
    try {
      // Get feedback
      final feedback = await SubmissionService.getSubmissionFeedback(submissionId);
      
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      if (feedback == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No feedback available yet. Your submission may still be under review.')),
        );
        return;
      }
      
      final feedbackLength = feedback['feedback_text']?.toString().length ?? 0;
      print('Received feedback: $feedbackLength characters');
      
      if (feedbackLength < 10) {
        print('WARNING: Very short feedback received: ${feedback['feedback_text']}');
        
        // Fall back to checking the feedback key if feedback_text is too short
        final altFeedback = feedback['feedback']?.toString() ?? '';
        if (altFeedback.length > feedbackLength) {
          print('Using alternative feedback field which has ${altFeedback.length} characters');
          feedback['feedback_text'] = altFeedback;
        }
      }
      
      // Show feedback dialog
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
                maxWidth: MediaQuery.of(context).size.width * 0.9,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Feedback: ${feedback['assignment_title']}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'From: ${feedback['teacher_name']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                        ),
                        if (feedback['is_ai'] == true)
                          Container(
                            margin: EdgeInsets.only(top: 8),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Colors.deepPurple.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.smart_toy, size: 14, color: Colors.deepPurple),
                                SizedBox(width: 4),
                                Text(
                                  'AI-Assisted',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.deepPurple,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  Divider(height: 1),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Display the feedback text
                          SelectableText(
                            _getFeedbackText(feedback),
                            style: TextStyle(fontSize: 16),
                          ),
                          if (feedback.containsKey('might_be_truncated') && feedback['might_be_truncated'] == true)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                                ),
                                child: Text(
                                  'The feedback appears to be truncated. Please ask your teacher for the complete version.',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.red[800],
                                  ),
                                ),
                              ),
                            )
                          else if ((_getFeedbackText(feedback).length) > 15000)
                            Padding(
                              padding: const EdgeInsets.only(top: 16.0),
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                                ),
                                child: Text(
                                  'Note: This feedback is quite long. If you have trouble viewing it all, please ask your teacher for the complete version.',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.amber[800],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Close'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      print('Error loading feedback: $e');
      print('Stack trace: $stackTrace');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading feedback: $e'),
          duration: Duration(seconds: 5),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _getFeedbackText(Map<String, dynamic> feedback) {
    String result = '';
    
    // Try both known keys for feedback
    if (feedback.containsKey('feedback_text') && 
        feedback['feedback_text'] != null && 
        feedback['feedback_text'].toString().isNotEmpty) {
      result = feedback['feedback_text'].toString();
      print('Using feedback_text field with ${result.length} characters');
    } else if (feedback.containsKey('feedback') && 
              feedback['feedback'] != null && 
              feedback['feedback'].toString().isNotEmpty) {
      result = feedback['feedback'].toString();
      print('Using feedback field with ${result.length} characters');
    }
    
    // If still empty, look for any key containing 'feedback'
    if (result.isEmpty) {
      for (var key in feedback.keys) {
        if (key.toString().toLowerCase().contains('feedback') && 
            feedback[key] != null && 
            feedback[key].toString().isNotEmpty) {
          result = feedback[key].toString();
          print('Found alternative feedback in field "$key" with ${result.length} characters');
          break;
        }
      }
    }
    
    // If still empty, return a useful message
    if (result.isEmpty) {
      print('WARNING: No feedback content found in any field');
      return 'No feedback content available. This may be due to a technical issue. Please contact your teacher or try again later.';
    }
    
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.classModel.color,
        elevation: 0,
        title: Text(widget.classModel.name),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('About this class'),
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Name: ${widget.classModel.name}'),
                      SizedBox(height: 8),
                      Text('Subject: ${widget.classModel.subject}'),
                      SizedBox(height: 8),
                      if (widget.classModel.description != null && widget.classModel.description!.isNotEmpty)
                        Text('Description: ${widget.classModel.description}'),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Class header
          Container(
            color: widget.classModel.color,
            padding: EdgeInsets.only(left: 20, right: 20, bottom: 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.classModel.subject,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Assignments',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Assignments list
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _assignments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No assignments yet',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _assignments.length,
                        padding: EdgeInsets.all(16),
                        itemBuilder: (context, index) {
                          final assignment = _assignments[index];
                          final isSubmitted = _submittedAssignments[assignment.id] ?? false;
                          
                          final now = DateTime.now();
                          final isOverdue = assignment.dueDate.isBefore(now);
                          
                          return Card(
                            margin: EdgeInsets.only(bottom: 16),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: isOverdue && !isSubmitted
                                  ? BorderSide(color: Colors.red, width: 1)
                                  : BorderSide.none,
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        isSubmitted
                                            ? Icons.assignment_turned_in
                                            : Icons.assignment_outlined,
                                        color: isSubmitted
                                            ? Colors.green
                                            : isOverdue
                                                ? Colors.red
                                                : Colors.blue,
                                        size: 28,
                                      ),
                                      SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              assignment.title,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today,
                                                  size: 16,
                                                  color: isOverdue ? Colors.red : Colors.grey[600],
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Due ${DateFormat('MMM d, yyyy').format(assignment.dueDate)}',
                                                  style: TextStyle(
                                                    color: isOverdue ? Colors.red : Colors.grey[600],
                                                  ),
                                                ),
                                                if (isOverdue && !isSubmitted)
                                                  Text(
                                                    ' (Overdue)',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (assignment.maxPoints != null)
                                              Padding(
                                                padding: EdgeInsets.only(top: 4),
                                                child: Text(
                                                  '${assignment.maxPoints} points',
                                                  style: TextStyle(color: Colors.grey[600]),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isSubmitted)
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: Text(
                                            'Submitted',
                                            style: TextStyle(
                                              color: Colors.green[800],
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    assignment.description,
                                    style: TextStyle(fontSize: 15),
                                  ),
                                  if (assignment.fileUrl != null)
                                    Padding(
                                      padding: EdgeInsets.only(top: 16),
                                      child: OutlinedButton.icon(
                                        icon: Icon(Icons.download),
                                        label: Text('View assignment materials'),
                                        onPressed: () => _openUrl(assignment.fileUrl),
                                        style: OutlinedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: 16),
                                  if (!isSubmitted)
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        icon: Icon(Icons.upload_file),
                                        label: Text('Submit Assignment'),
                                        onPressed: () => _submitAssignment(assignment),
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(vertical: 12),
                                          backgroundColor: isOverdue ? Colors.red : Colors.blue,
                                        ),
                                      ),
                                    ),
                                  if (isSubmitted)
                                    SizedBox(
                                      width: double.infinity,
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: OutlinedButton.icon(
                                              icon: Icon(Icons.feedback_outlined),
                                              label: Text('View Feedback'),
                                              onPressed: () => _showFeedback(assignment.id),
                                              style: OutlinedButton.styleFrom(
                                                padding: EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              icon: Icon(Icons.upload_file),
                                              label: Text('Resubmit'),
                                              onPressed: () => _submitAssignment(assignment),
                                              style: ElevatedButton.styleFrom(
                                                padding: EdgeInsets.symmetric(vertical: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 