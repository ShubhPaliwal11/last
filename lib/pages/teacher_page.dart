import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../utils/supabase_config.dart';
import '../models/class_model.dart';
import '../services/class_service.dart';
import '../services/assignment_service.dart';
import 'login.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:async';
import '../services/submission_service.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../services/file_url_service.dart';
import 'dart:developer' as dev;

class TeacherHomePage extends StatefulWidget {
  @override
  _TeacherHomePageState createState() => _TeacherHomePageState();
}

class _TeacherHomePageState extends State<TeacherHomePage> {
  String? userName;
  int _selectedIndex = 0;
  bool _isLoading = false;
  List<ClassModel> _teacherClasses = [];
  Map<String, int> _classAssignmentCounts = {};
  Map<String, int> _classStudentCounts = {};
  List<Map<String, dynamic>> _pendingSubmissions = [];
  List<Map<String, dynamic>> _reviewedSubmissions = [];
  bool _loadingSubmissions = false;
  bool _debugMode = true; // Set to true to enable detailed logging
  String? _userId;
  
  // Add overlay entry as a class variable for loading state
  OverlayEntry? _loadingOverlay;

  @override
  void initState() {
    super.initState();
    _debugMode = true; // Enable debugging
    _userId = supabase.auth.currentUser?.id;
    print('Teacher Page initialized with user ID: $_userId');
    
    // Set up file URL system and migrate existing URLs
    _setupFileUrlSystem();
    
    // Fix any truncated URLs in the database
    _fixDatabaseUrls();
    
    // Initial data load
    _loadUserProfile();
    _loadTeacherClasses();
    _loadPendingSubmissions();
  }

  Future<void> _loadUserProfile() async {
    final user = await supabase.auth.currentUser;
    if (user != null) {
      final profile = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .single();
    setState(() {
        userName = profile['name'];
      });
    }
  }

  Future<void> _loadTeacherClasses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await supabase.auth.currentUser;
      if (user != null) {
        final classes = await ClassService.getTeacherClasses(user.id);
        
        final assignmentCountsFutures = classes.map((classModel) async {
          return {
            'classId': classModel.id,
            'count': await AssignmentService.getAssignmentDueCount(classModel.id),
          };
        }).toList();
        
        final studentCountsFutures = classes.map((classModel) async {
          return {
            'classId': classModel.id,
            'count': await ClassService.getStudentCount(classModel.id),
          };
        }).toList();
        
        final assignmentCounts = await Future.wait(assignmentCountsFutures);
        final studentCounts = await Future.wait(studentCountsFutures);
        
        setState(() {
          _teacherClasses = classes;
          _isLoading = false;
          
          for (var item in assignmentCounts) {
            _classAssignmentCounts[item['classId'].toString()] = (item['count'] as num).toInt();
          }
          
          for (var item in studentCounts) {
            _classStudentCounts[item['classId'].toString()] = (item['count'] as num).toInt();
          }
        });
      }
    } catch (e) {
      print('Error loading classes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPendingSubmissions() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final user = await supabase.auth.currentUser;
      if (user == null) {
        print('No user found');
        return;
      }

      print('Teacher Page initialized with user ID: ${user.id}');

      // Load both pending and reviewed submissions
      final pendingSubmissions = await SubmissionService.getPendingSubmissionsForTeacher(user.id);
      final reviewedSubmissions = await SubmissionService.getReviewedSubmissionsForTeacher(user.id);

      if (mounted) {
        setState(() {
          _pendingSubmissions = pendingSubmissions;
          _reviewedSubmissions = reviewedSubmissions;
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error in _loadPendingSubmissions: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    
    if (index == 2) {
      _loadPendingSubmissions();
    }
  }

  Future<void> _createClass() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController subjectController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create New Class'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Class Name',
                  hintText: 'e.g., Mathematics 101',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: subjectController,
                decoration: InputDecoration(
                  labelText: 'Subject',
                  hintText: 'e.g., Mathematics',
                ),
              ),
              SizedBox(height: 12),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  hintText: 'Enter class description',
                ),
                maxLines: 3,
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
              if (nameController.text.trim().isEmpty || subjectController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter both name and subject')),
                );
                return;
              }
              
              Navigator.pop(context, {
                'name': nameController.text.trim(),
                'subject': subjectController.text.trim(),
                'description': descriptionController.text.trim(),
              });
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      final user = await supabase.auth.currentUser;
      if (user != null) {
        try {
          setState(() {
            _isLoading = true;
          });
          
          await ClassService.createClass(
            name: result['name']!,
            subject: result['subject']!,
            teacherId: user.id,
            description: result['description'],
          );
          
          await _loadTeacherClasses();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Class created successfully!')),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating class: $e')),
          );
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
  
  Future<void> _generateClassCode(ClassModel classModel) async {
    try {
      final code = await ClassService.generateClassCode(classModel.id);
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Class Join Code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Share this code with your students:'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      code,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    IconButton(
                      icon: Icon(Icons.copy),
        onPressed: () {
                        Clipboard.setData(ClipboardData(text: code));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Code copied to clipboard')),
                        );
                      },
                    ),
                  ],
                ),
              ),
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating class code: $e')),
      );
    }
  }

  Future<void> _createAssignment() async {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController pointsController = TextEditingController();
    
    DateTime? selectedDueDate = DateTime.now().add(Duration(days: 7));
    TimeOfDay selectedDueTime = TimeOfDay.now();
    String? selectedClassId;
    String? uploadedFileUrl;
    String? uploadedFileName;
    
    // Function to upload file to Supabase storage
    Future<void> _uploadFile() async {
      try {
        setState(() {
          _isLoading = true;
        });
        
        print('Starting file upload process');
        
        // For web platform, we skip the file path completely and pass a placeholder
        // The actual file will be picked again in the AssignmentService
        final user = await supabase.auth.currentUser;
        if (user == null) {
          throw Exception('User not authenticated');
        }
        
        // Use a dummy file path for web - the actual file will be picked inside the service
        final dummyPath = 'document.pdf';
        
        final fileUrl = await AssignmentService.uploadAssignmentFile(dummyPath, user.id);
        
        if (fileUrl == null) {
          throw Exception('Failed to upload file');
        }
        
        print('File uploaded successfully: $fileUrl');
        
        // Now show dialog to create a new assignment with this file
        _showCreateAssignmentDialog(fileUrl);
      } catch (e) {
        print('Error uploading file: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading file: $e')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
        return AlertDialog(
              title: Text('Create Assignment'),
              content: SingleChildScrollView(
                child: Column(
            mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Class',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedClassId,
                      hint: Text('Select a class'),
                      isExpanded: true,
                      items: _teacherClasses.map((classModel) {
                        return DropdownMenuItem<String>(
                          value: classModel.id,
                          child: Text(classModel.name),
                        );
                      }).toList(),
                onChanged: (value) {
                        setState(() {
                          selectedClassId = value;
                        });
                },
              ),
                    SizedBox(height: 16),
                    
                    // Title Field
              TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Assignment Title',
                        hintText: 'e.g., Midterm Project',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Description Field
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Assignment Description',
                        hintText: 'Provide details about the assignment',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: 16),
                    
                    // Points Field
                    TextField(
                      controller: pointsController,
                      decoration: InputDecoration(
                        labelText: 'Points',
                        hintText: 'e.g., 100',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    SizedBox(height: 16),
                    
                    // Due Date Picker
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.calendar_today),
                            label: Text(
                              selectedDueDate != null
                                  ? '${selectedDueDate!.day}/${selectedDueDate!.month}/${selectedDueDate!.year}'
                                  : 'Select Due Date',
                            ),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDueDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(Duration(days: 365)),
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  selectedDueDate = pickedDate;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.access_time),
                            label: Text(
                              '${selectedDueTime.hour}:${selectedDueTime.minute.toString().padLeft(2, '0')}'
                            ),
                            onPressed: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: selectedDueTime,
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  selectedDueTime = pickedTime;
                                });
                              }
                            },
                          ),
              ),
            ],
          ),
                    SizedBox(height: 16),
                    
                    // File Upload
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Assignment Materials (Optional)'),
                        SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: Icon(Icons.upload_file),
                          label: Text('Upload File'),
                          onPressed: () async {
                            await _uploadFile();
                            setState(() {}); // Refresh the dialog to show uploaded file
                          },
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),
                        SizedBox(height: 8),
                        if (uploadedFileName != null)
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.insert_drive_file, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    uploadedFileName!,
                                    style: TextStyle(fontSize: 14),
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
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty ||
                        selectedClassId == null ||
                        selectedDueDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please fill in all required fields')),
                      );
                      return;
                    }
                    
                    Navigator.pop(context, {
                      'title': titleController.text,
                      'description': descriptionController.text,
                      'class_id': selectedClassId,
                      'due_date': DateTime(
                        selectedDueDate!.year,
                        selectedDueDate!.month,
                        selectedDueDate!.day,
                        selectedDueTime.hour,
                        selectedDueTime.minute,
                      ),
                      'points': pointsController.text.isNotEmpty 
                          ? int.parse(pointsController.text) 
                          : null,
                      'file_url': uploadedFileUrl,
                    });
                  },
                  child: Text('Create'),
            ),
          ],
        );
      },
    );
      },
    ).then((result) async {
      if (result != null) {
        final user = await supabase.auth.currentUser;
        if (user != null) {
          try {
            setState(() {
              _isLoading = true;
            });
            
            await AssignmentService.createAssignment(
              title: result['title'],
              description: result['description'],
              classId: result['class_id'],
              teacherId: user.id,
              dueDate: result['due_date'],
              maxPoints: result['points'],
              fileUrl: result['file_url'],
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Assignment created successfully!')),
            );
            
            // Refresh the class data to show updated assignment counts
            await _loadTeacherClasses();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error creating assignment: $e')),
            );
          } finally {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    });
  }

  void _showCreateAssignmentDialog(String fileUrl) {
    final TextEditingController titleController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController pointsController = TextEditingController();
    
    DateTime? selectedDueDate = DateTime.now().add(Duration(days: 7));
    TimeOfDay selectedDueTime = TimeOfDay.now();
    String? selectedClassId;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Create Assignment with File'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // File uploaded info
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'File Uploaded Successfully',
                                  style: TextStyle(
                                    color: Colors.green[800],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'You can now create an assignment with this file',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.green[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Class Dropdown
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Select Class',
                        border: OutlineInputBorder(),
                      ),
                      value: selectedClassId,
                      hint: Text('Select a class'),
                      isExpanded: true,
                      items: _teacherClasses.map((classModel) {
                        return DropdownMenuItem<String>(
                          value: classModel.id,
                          child: Text(classModel.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedClassId = value;
                        });
                      },
                    ),
                    SizedBox(height: 16),
                    
                    // Title Field
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Assignment Title',
                        hintText: 'e.g., Midterm Project',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    SizedBox(height: 16),
                    
                    // Description Field
                    TextField(
                      controller: descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Assignment Description',
                        hintText: 'Provide details about the assignment',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    SizedBox(height: 16),
                    
                    // Points Field
                    TextField(
                      controller: pointsController,
                      decoration: InputDecoration(
                        labelText: 'Points',
                        hintText: 'e.g., 100',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    SizedBox(height: 16),
                    
                    // Due Date Picker
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.calendar_today),
                            label: Text(
                              selectedDueDate != null
                                  ? '${selectedDueDate!.day}/${selectedDueDate!.month}/${selectedDueDate!.year}'
                                  : 'Select Due Date',
                            ),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedDueDate ?? DateTime.now(),
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(Duration(days: 365)),
                              );
                              if (pickedDate != null) {
                                setState(() {
                                  selectedDueDate = pickedDate;
                                });
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: Icon(Icons.access_time),
                            label: Text(
                              '${selectedDueTime.hour}:${selectedDueTime.minute.toString().padLeft(2, '0')}'
                            ),
                            onPressed: () async {
                              final pickedTime = await showTimePicker(
                                context: context,
                                initialTime: selectedDueTime,
                              );
                              if (pickedTime != null) {
                                setState(() {
                                  selectedDueTime = pickedTime;
                                });
                              }
                            },
                          ),
                        ),
                      ],
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
                    if (titleController.text.isEmpty ||
                        descriptionController.text.isEmpty ||
                        selectedClassId == null ||
                        selectedDueDate == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please fill in all required fields')),
                      );
                      return;
                    }
                    
                    Navigator.pop(context, {
                      'title': titleController.text,
                      'description': descriptionController.text,
                      'class_id': selectedClassId,
                      'due_date': DateTime(
                        selectedDueDate!.year,
                        selectedDueDate!.month,
                        selectedDueDate!.day,
                        selectedDueTime.hour,
                        selectedDueTime.minute,
                      ),
                      'points': pointsController.text.isNotEmpty 
                          ? int.parse(pointsController.text) 
                          : null,
                      'file_url': fileUrl,
                    });
                  },
                  child: Text('Create'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) async {
      if (result != null) {
        final user = await supabase.auth.currentUser;
        if (user != null) {
          try {
            setState(() {
              _isLoading = true;
            });
            
            await AssignmentService.createAssignment(
              title: result['title'],
              description: result['description'],
              classId: result['class_id'],
              teacherId: user.id,
              dueDate: result['due_date'],
              maxPoints: result['points'],
              fileUrl: result['file_url'],
            );
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Assignment created successfully!')),
            );
            
            // Refresh the class data to show updated assignment counts
            await _loadTeacherClasses();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error creating assignment: $e')),
            );
          } finally {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    });
  }

  // Utility function to check and fix truncated URLs
  String _fixTruncatedUrl(String url, String type) {
    print('Checking URL format for $type: $url');
    
    if (url.isEmpty) {
      print('Empty $type URL');
      return url;
    }
    
    // Check for truncated URLs (ending with underscore)
    if (url.endsWith('_')) {
      print('Found truncated $type URL ending with underscore');
      return url + 'document.pdf';
    }
    
    // Ensure URL has .pdf extension if it's a relative path
    if (!url.startsWith('http') && !url.toLowerCase().endsWith('.pdf')) {
      print('Adding .pdf extension to $type URL');
      return url + '.pdf';
    }
    
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teacher Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator())
        : IndexedStack(
            index: _selectedIndex,
        children: [
              // Classes Screen
              Column(
                children: [
                  Padding(
            padding: EdgeInsets.all(16),
            child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                        Text(
                          'My Classes',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _createClass,
                          icon: Icon(Icons.add),
                          label: Text('Create Class'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _teacherClasses.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                              Icon(Icons.school_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                    Text(
                                'No Classes Yet',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Create your first class to get started',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _createClass,
                                icon: Icon(Icons.add),
                                label: Text('Create Class'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.all(16),
                          itemCount: _teacherClasses.length,
                          itemBuilder: (context, index) {
                            final classModel = _teacherClasses[index];
                            return _buildClassCard(
                              classModel,
                              _classAssignmentCounts[classModel.id] ?? 0,
                              _classStudentCounts[classModel.id] ?? 0,
                            );
                          },
                        ),
                  ),
                ],
              ),

              // Assignments Screen
              Column(
                children: [
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Assignments',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _createAssignment,
                          icon: Icon(Icons.add),
                          label: Text('Create Assignment'),
                ),
              ],
            ),
          ),
          Expanded(
                    child: _teacherClasses.isEmpty
                      ? Center(
              child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                children: [
                              Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No Classes Created',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Create a class before adding assignments',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _createClass,
                                icon: Icon(Icons.add),
                                label: Text('Create Class'),
                              ),
                            ],
                          ),
                        )
                      : FutureBuilder<List<Map<String, dynamic>>>(
                          future: _loadAssignmentsForTeacher(),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Center(child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                                    Icon(Icons.error_outline, size: 64, color: Colors.red),
                                    SizedBox(height: 16),
                                    Text(
                                      'Error loading assignments',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 8),
                                    Text(snapshot.error.toString()),
                                  ],
                                ),
                              );
                            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                                    SizedBox(height: 16),
                                    Text(
                                      'No Assignments Yet',
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'Create your first assignment',
                                      style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
                              );
                            } else {
                              return ListView.builder(
                                padding: EdgeInsets.all(16),
                                itemCount: snapshot.data!.length,
                                itemBuilder: (context, index) {
                                  final assignment = snapshot.data![index];
                                  return Card(
                                    margin: EdgeInsets.only(bottom: 16),
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  assignment['title'] ?? 'Untitled Assignment',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (assignment['max_points'] != null)
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[100],
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    '${assignment['max_points']} pts',
                                                    style: TextStyle(
                                                      color: Colors.blue[800],
                                                      fontWeight: FontWeight.bold,
                                                    ),
            ),
          ),
        ],
      ),
                                          SizedBox(height: 8),
                                          Text(
                                            '${assignment['class_name'] ?? 'Unknown Class'}',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                          SizedBox(height: 4),
                                          Text(
                                            'Due: ${_formatDate(assignment['due_date'])}',
                                            style: TextStyle(color: Colors.grey[600]),
                                          ),
                                          SizedBox(height: 8),
                                          if (assignment['description'] != null && assignment['description'].toString().isNotEmpty)
                                            Text(
                                              assignment['description'],
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              if (assignment['file_url'] != null && assignment['file_url'].toString().isNotEmpty)
                                                TextButton.icon(
                                                  icon: Icon(Icons.file_open, size: 16),
                                                  label: Text('View'),
                                                  onPressed: () => _openAssignmentFile(assignment['file_url']),
                                                ),
                                              SizedBox(width: 8),
                                              TextButton.icon(
                                                icon: Icon(Icons.edit, size: 16),
                                                label: Text('Edit'),
        onPressed: () {
                                                  // Show edit dialog
                                                },
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            }
                          },
                        ),
                  ),
                ],
              ),

              // Reviews Screen (TabBarView)
              DefaultTabController(
                length: 2,
                child: Column(
      children: [
                    TabBar(
                      tabs: [
                        Tab(text: 'Pending Reviews'),
                        Tab(text: 'Reviewed Submissions'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          // Pending Submissions Tab
                          _loadingSubmissions
                            ? Center(child: CircularProgressIndicator())
                            : _pendingSubmissions.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                                      SizedBox(height: 16),
                                      Text(
                                        'All caught up!',
                                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'No pending submissions to review',
                                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                      ),
                                      SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        onPressed: _loadPendingSubmissions,
                                        icon: Icon(Icons.refresh),
                                        label: Text('Refresh'),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _pendingSubmissions.length,
                                  itemBuilder: (context, index) {
                                    final submission = _pendingSubmissions[index];
                                    return _buildSubmissionCard(submission, isPending: true);
                                  },
                                ),

                          // Reviewed Submissions Tab
                          _loadingSubmissions
                            ? Center(child: CircularProgressIndicator())
                            : _reviewedSubmissions.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
      children: [
                                      Icon(Icons.history, size: 64, color: Colors.grey),
                                      SizedBox(height: 16),
                                      Text(
                                        'No reviewed submissions yet',
                                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Reviewed submissions will appear here',
                                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _reviewedSubmissions.length,
                                  itemBuilder: (context, index) {
                                    final submission = _reviewedSubmissions[index];
                                    return _buildSubmissionCard(submission, isPending: false);
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.class_),
            label: 'Classes',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Assignments',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.rate_review),
            label: 'Reviews',
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard(Map<String, dynamic> submission, {required bool isPending}) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(submission['assignment_title'] ?? 'Unknown Assignment'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
      children: [
            Text('Student: ${submission['student_name'] ?? 'Unknown Student'}'),
            Text('Submitted: ${_formatDate(submission['submitted_at'])}'),
            if (!isPending && submission['points'] != null)
              Text('Points: ${submission['points']}'),
          ],
        ),
        trailing: isPending
          ? ElevatedButton(
              onPressed: () => _showFeedbackDialog(submission),
              child: Text('Review'),
            )
          : Icon(Icons.check_circle, color: Colors.green),
        onTap: () => _showSubmissionDetails(submission),
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return 'Unknown date';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, y h:mm a').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Widget _buildClassCard(ClassModel classModel, int assignmentCount, int studentCount) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to class detail
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: classModel.color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
        padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                          classModel.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
            Text(
                          classModel.subject,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
            ),
          ],
        ),
      ),
                  PopupMenuButton(
                    icon: Icon(Icons.more_vert, color: Colors.white),
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.link, color: Colors.grey[700]),
                            SizedBox(width: 12),
                            Text('Generate join code'),
                          ],
                        ),
                        value: 'code',
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.edit, color: Colors.grey[700]),
                            SizedBox(width: 12),
                            Text('Edit'),
                          ],
                        ),
                        value: 'edit',
                      ),
                      PopupMenuItem(
                        child: Row(
                          children: [
                            Icon(Icons.archive, color: Colors.grey[700]),
                            SizedBox(width: 12),
                            Text('Archive'),
                          ],
                        ),
                        value: 'archive',
                      ),
                    ],
                    onSelected: (value) {
                      if (value == 'code') {
                        _generateClassCode(classModel);
                      } else if (value == 'archive') {
                        // Archive class
                      }
                    },
                  ),
                ],
              ),
            ),
            Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                      Icon(Icons.assignment_outlined, size: 20, color: Colors.grey[600]),
                SizedBox(width: 8),
                Text(
                        '$assignmentCount assignments due',
                        style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
            SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 20, color: Colors.grey[600]),
                      SizedBox(width: 8),
            Text(
                        '$studentCount students',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmissionOptions(Map<String, dynamic> submission, String assignmentTitle) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.open_in_new),
            title: Text('View Submission'),
            onTap: () {
              Navigator.pop(context);
              _openSubmissionFile(submission['file_url']);
            },
          ),
          ListTile(
            leading: Icon(Icons.rate_review),
            title: Text('Grade Manually'),
            onTap: () {
              Navigator.pop(context);
              _showGradeDialog(submission, assignmentTitle);
            },
          ),
          ListTile(
            leading: Icon(Icons.smart_toy),
            title: Text('Analyze with AI'),
            onTap: () {
              Navigator.pop(context);
              _analyzeWithAI(submission);
            },
          ),
          ListTile(
            leading: Icon(Icons.bug_report),
            title: Text('Debug File URLs'),
            onTap: () {
              Navigator.pop(context);
              _debugFileUrls(submission['id']);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _analyzeWithAI(Map<String, dynamic> submission) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    try {
      final assignmentId = submission['assignment_id'];
      final submissionId = submission['id'];
      
      print('Starting AI analysis for submission ID: $submissionId');
      print('Getting assignment details for ID: $assignmentId');
      
      // First verify that we have a valid submission file
      final submissionFileUrl = submission['file_url'];
      if (submissionFileUrl == null || submissionFileUrl.isEmpty) {
        print('Error: Missing submission file URL in submission record');
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: No submission file to analyze')),
        );
        return;
      }
      
      // Get the assignment details
      final assignmentResponse = await supabase
          .from('assignments')
          .select('*')
          .eq('id', assignmentId)
          .single();
      
      final assignmentTitle = assignmentResponse['title'] ?? 'Untitled Assignment';
      final assignmentDescription = assignmentResponse['description'] ?? '';
      final assignmentFileUrl = assignmentResponse['file_url'];
      final teacherId = assignmentResponse['teacher_id'];
      
      // Check if we have a valid assignment file
      bool hasAssignmentFile = assignmentFileUrl != null && assignmentFileUrl.isNotEmpty;
      
      if (!hasAssignmentFile) {
        print('Warning: No assignment file URL found for assignment: $assignmentTitle (ID: $assignmentId)');
        
        // Show a dialog asking if they want to upload a file for this assignment
        final action = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Missing Assignment File'),
            content: Text(
              'This assignment does not have an uploaded PDF file for the AI to reference. '
              'The analysis may be less accurate without the original assignment document.\n\n'
              'What would you like to do?'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, 'continue'),
                child: Text('Continue Without File'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, 'cancel'),
                child: Text('Cancel Analysis'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, 'upload'),
                child: Text('Upload Assignment File'),
              ),
            ],
          ),
        );
        
        // Close loading dialog
        Navigator.pop(context);
        
        if (action == 'cancel') {
          return;
        } else if (action == 'upload') {
          // Show file picker and upload new assignment file
          try {
            // Get current user ID for the upload
            final userId = supabase.auth.currentUser?.id;
            if (userId == null) {
              throw Exception('User not authenticated');
            }
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please select the assignment PDF file')),
            );
            
            // Upload the file and get the URL
            final filePath = await AssignmentService.uploadAssignmentFile('', teacherId);
            
            // Update the assignment with the new file URL
            if (filePath != null && filePath.isNotEmpty) {
              await AssignmentService.updateAssignmentFile(assignmentId, filePath);
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Assignment file uploaded successfully')),
              );
              
              // Restart the analysis process with the new file
              _analyzeWithAI(submission);
              return;
            } else {
              throw Exception('Failed to upload assignment file');
            }
          } catch (e) {
            print('Error uploading assignment file: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error uploading file: $e')),
            );
            return;
          }
        }
        // If 'continue', proceed with analysis without the file
      }
      
      // Show loading dialog again if it was closed
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Generate AI feedback using submission and assignment IDs
      final aiFeedback = await SubmissionService.getAIFeedback(
        assignmentTitle: assignmentTitle,
        assignmentDescription: assignmentDescription,
        studentName: submission['student_name'] ?? 'Unknown Student',
        submissionId: submissionId,
        assignmentId: assignmentId,
      );
      
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      // Show AI feedback in dialog
      if (context.mounted) _showAIFeedbackDialog(submission, aiFeedback, assignmentTitle);
    } catch (e) {
      // Close loading dialog
      if (context.mounted) Navigator.pop(context);
      
      print('Error in _analyzeWithAI: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error analyzing submission: $e')),
      );
    }
  }
  
  void _showAIFeedbackDialog(Map<String, dynamic> submission, String feedback, String assignmentTitle) {
    final pointsController = TextEditingController(text: '80'); // Default points
    bool assignPoints = false; // Option to assign points with AI feedback

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8, // 80% of screen height
                maxWidth: MediaQuery.of(context).size.width * 0.9,   // 90% of screen width
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
                          'AI Feedback for $assignmentTitle',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Student: ${submission['student_name']}',
                          style: TextStyle(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16.0),
                      child: SelectableText(
                        feedback,
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Points option
                        Row(
                          children: [
                            Checkbox(
                              value: assignPoints,
                              onChanged: (value) {
                                setState(() {
                                  assignPoints = value ?? false;
                                });
                              },
                            ),
                            Text('Assign points with this feedback'),
                          ],
                        ),
                        if (assignPoints)
                          Padding(
                            padding: const EdgeInsets.only(left: 32.0, right: 16.0, top: 8.0),
          child: Row(
            children: [
                                Expanded(
                                  child: TextField(
                                    controller: pointsController,
                                    decoration: InputDecoration(
                                      labelText: 'Points',
                                      border: OutlineInputBorder(),
                                    ),
                                    keyboardType: TextInputType.number,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  ButtonBar(
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text('Close'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          // Save the AI feedback to the database
                          try {
                            print('Starting feedback save process...');
                            print('Submission ID: ${submission['id']}');
                            print('Feedback length: ${feedback.length}');
                            
                            // Close dialog first to prevent double-taps
                            Navigator.pop(context);
                            
                            // Show a loading overlay that can't get stuck
                            bool isSaveComplete = false;
                            
                            // Create and insert overlay
                            if (context.mounted) {
                              // Remove any existing overlay first
                              if (_loadingOverlay != null) {
                                _loadingOverlay!.remove();
                                _loadingOverlay = null;
                              }
                              
                              _loadingOverlay = OverlayEntry(
                                builder: (context) => Material(
                                  color: Colors.black54,
                                  child: Center(
                                    child: Container(
                                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(),
                                          SizedBox(height: 16),
                                          Text('Saving feedback...'),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                              
                              // Insert the overlay into the widget tree
                              Overlay.of(context).insert(_loadingOverlay!);
                              print("Inserted loading overlay");
                            }
                            
                            // Function to close the overlay safely
                            void hideLoading() {
                              if (_loadingOverlay != null) {
                                _loadingOverlay!.remove();
                                _loadingOverlay = null;
                                print("Removed loading overlay");
                              }
                            }
                            
                            // Get points if option is enabled
                            int? points;
                            if (assignPoints) {
                              points = int.tryParse(pointsController.text.trim());
                              if (points == null) {
                                print('Points text could not be parsed: ${pointsController.text}');
                              }
                            }
                            
                            print('Points to assign: $points');
                            
                            // Start a timeout timer
                            Timer? timeoutTimer;
                            timeoutTimer = Timer(Duration(seconds: 60), () {
                              print('Save operation timeout triggered after 60 seconds');
                              if (!isSaveComplete) {
                                // Remove the overlay if it's still showing
                                hideLoading();
                                
                                // Show timeout message
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('The save operation is taking longer than expected but may still complete in the background.'),
                                      duration: Duration(seconds: 5),
      ),
    );
  }
}
                            });

                            // Execute the save operation in a try-catch block
                            try {
                              await SubmissionService.saveTeacherFeedback(
                                submissionId: submission['id'],
                                feedback: feedback, 
                                points: points,
                                isFromAI: true,
                              );
                              
                              // Mark that the save is complete
                              isSaveComplete = true;
                              
                              // Cancel the timeout timer
                              if (timeoutTimer != null && timeoutTimer.isActive) {
                                timeoutTimer.cancel();
                              }
                              
                              print('Feedback saved successfully');
                              
                              // Remove loading overlay
                              hideLoading();
                              
                              // Show success UI
                              if (context.mounted) {
                                // Force close any remaining dialogs
                                Navigator.of(context).popUntil((route) => route.isFirst);
                                
                                // Show success message using SnackBar
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('AI feedback saved successfully and will be visible to the student'),
                                    duration: Duration(seconds: 3),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                                
                                // Show success dialog
                                showDialog(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (BuildContext dialogContext) {
                                    // Auto-close after 2 seconds
                                    Future.delayed(Duration(seconds: 2), () {
                                      if (dialogContext.mounted) {
                                        Navigator.of(dialogContext).pop();
                                      }
                                    });
                                    
                                    return AlertDialog(
                                      backgroundColor: Colors.green[100],
                                      title: Text('Success'),
                                      content: Text('Feedback saved successfully!'),
                                    );
                                  },
                                );
                                
                                // Refresh submissions list to remove reviewed submission
                                Future.delayed(Duration(milliseconds: 500), () {
                                  if (mounted) _loadPendingSubmissions();
                                });
                              }
                            } catch (saveError) {
                              print('Error in saveTeacherFeedback: $saveError');
                              
                              // Mark that the save operation is complete (but with error)
                              isSaveComplete = true;
                              
                              // Cancel the timeout timer
                              if (timeoutTimer != null && timeoutTimer.isActive) {
                                timeoutTimer.cancel();
                              }
                              
                              // Remove loading overlay
                              hideLoading();
                              
                              // Show error message
                              if (context.mounted) {
                                // Force close any remaining dialogs
                                Navigator.of(context).popUntil((route) => route.isFirst);
                                
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error saving feedback: $saveError'),
                                    duration: Duration(seconds: 5),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            print('Error in feedback save process: $e');
                            
                            if (context.mounted) {
                              // Force close any remaining dialogs
                              Navigator.of(context).popUntil((route) => route.isFirst);
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error starting save process: $e'),
                                  duration: Duration(seconds: 5),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: Text('Save Feedback'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  void _showFeedbackDialog(Map<String, dynamic> submission) {
    final feedbackController = TextEditingController();
    final pointsController = TextEditingController(text: '80'); // Default points
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review Submission'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assignment: ${submission['assignment_title']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                'Student: ${submission['student_name']}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                decoration: InputDecoration(
                  labelText: 'Feedback',
                  border: OutlineInputBorder(),
                  hintText: 'Enter your feedback for the student',
                ),
                maxLines: 5,
              ),
              SizedBox(height: 16),
              TextField(
                controller: pointsController,
                decoration: InputDecoration(
                  labelText: 'Points',
                  border: OutlineInputBorder(),
                  hintText: 'Enter points (e.g., 85)',
                ),
                keyboardType: TextInputType.number,
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
            onPressed: () async {
              if (feedbackController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter feedback')),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                int points = int.tryParse(pointsController.text) ?? 0;
                
                // Show loading overlay
                if (context.mounted) {
                  if (_loadingOverlay != null) {
                    _loadingOverlay!.remove();
                    _loadingOverlay = null;
                  }
                  
                  _loadingOverlay = OverlayEntry(
                    builder: (context) => Material(
                      color: Colors.black54,
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Saving feedback...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                  
                  Overlay.of(context).insert(_loadingOverlay!);
                }
                
                await SubmissionService.saveTeacherFeedback(
                  submissionId: submission['id'],
                  feedback: feedbackController.text,
                  points: points,
                  isFromAI: false,
                );
                
                // Remove loading overlay
                if (_loadingOverlay != null) {
                  _loadingOverlay!.remove();
                  _loadingOverlay = null;
                }
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Feedback saved successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Refresh the submissions list
                  _loadPendingSubmissions();
                }
              } catch (e) {
                // Remove loading overlay
                if (_loadingOverlay != null) {
                  _loadingOverlay!.remove();
                  _loadingOverlay = null;
                }
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving feedback: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }

  void _showSubmissionDetails(Map<String, dynamic> submission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Submission Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assignment: ${submission['assignment_title']}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Student: ${submission['student_name']}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 8),
              Text(
                'Submitted: ${_formatDate(submission['submitted_at'])}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              if (submission['points'] != null) ...[
                SizedBox(height: 8),
                Text(
                  'Points: ${submission['points']}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
              SizedBox(height: 16),
              OutlinedButton.icon(
                icon: Icon(Icons.file_open),
                label: Text('View Submission'),
                onPressed: () {
                  Navigator.pop(context);
                  _openSubmissionFile(submission['file_url']);
                },
              ),
              if (!submission['status'].toString().toLowerCase().contains('reviewed')) ...[
                OutlinedButton.icon(
                  icon: Icon(Icons.rate_review),
                  label: Text('Review Submission'),
                  onPressed: () {
                    Navigator.pop(context);
                    _showFeedbackDialog(submission);
                  },
                ),
                OutlinedButton.icon(
                  icon: Icon(Icons.smart_toy),
                  label: Text('Analyze with AI'),
                  onPressed: () {
                    Navigator.pop(context);
                    _analyzeWithAI(submission);
                  },
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  // Fix any truncated URLs in the database
  Future<void> _fixDatabaseUrls() async {
    try {
      print('Checking database for truncated URLs...');
      await AssignmentService.fixTruncatedFileUrls();
      print('Database URL check completed');
    } catch (e) {
      print('Error fixing database URLs: $e');
      // Don't show an error to the user, just log it
    }
  }

  // Set up the file URL system
  Future<void> _setupFileUrlSystem() async {
    try {
      print('Setting up file URL system...');
      
      // Create table if needed and migrate existing file URLs
      await FileUrlService.createFileUrlsTable();
      await FileUrlService.migrateExistingFiles();
      
      print('File URL system setup complete');
    } catch (e) {
      print('Error setting up file URL system: $e');
      // Don't show error to user, it's a background task
      // But we'll need to create the table manually if this fails
    }
  }

  // Debug function to check file paths
  Future<void> _debugFileUrls(String submissionId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      print('Debugging file URLs for submission ID: $submissionId');
      
      // Get submission details
      final submission = await supabase
          .from('submissions')
          .select('*, assignments(*)')
          .eq('id', submissionId)
          .single();
      
      final submissionFileUrl = submission['file_url'];
      final assignmentId = submission['assignment_id'];
      final assignmentDetails = submission['assignments'];
      final assignmentFileUrl = assignmentDetails != null ? assignmentDetails['file_url'] : null;
      
      print('Raw file paths:');
      print('- Submission file_url: $submissionFileUrl');
      print('- Assignment file_url: $assignmentFileUrl');
      
      // Test Supabase storage URLs
      final supabaseUrl = 'https://shrnxdbbaxfhjaxelbjl.supabase.co';
      
      List<Map<String, dynamic>> urlTests = [];
      
      // Test submission URL variations
      if (submissionFileUrl != null && submissionFileUrl.isNotEmpty) {
        final submissionUrls = [
          '$supabaseUrl/storage/v1/object/public/submissions/$submissionFileUrl',
          '$supabaseUrl/storage/v1/object/public/submissions/$submissionFileUrl.pdf',
        ];
        
        for (String url in submissionUrls) {
          try {
            print('Testing URL: $url');
            final response = await http.head(Uri.parse(url));
            urlTests.add({
              'url': url,
              'status': response.statusCode,
              'type': 'submission',
              'works': response.statusCode >= 200 && response.statusCode < 300
            });
          } catch (e) {
            urlTests.add({
              'url': url,
              'status': 'Error',
              'type': 'submission',
              'works': false
            });
          }
        }
      }
      
      // Test assignment URL variations
      if (assignmentFileUrl != null && assignmentFileUrl.isNotEmpty) {
        final assignmentUrls = [
          '$supabaseUrl/storage/v1/object/public/assignments/$assignmentFileUrl',
          '$supabaseUrl/storage/v1/object/public/assignments/$assignmentFileUrl.pdf',
        ];
        
        for (String url in assignmentUrls) {
          try {
            print('Testing URL: $url');
            final response = await http.head(Uri.parse(url));
            urlTests.add({
              'url': url,
              'status': response.statusCode,
              'type': 'assignment',
              'works': response.statusCode >= 200 && response.statusCode < 300
            });
          } catch (e) {
            urlTests.add({
              'url': url,
              'status': 'Error',
              'type': 'assignment',
              'works': false
            });
          }
        }
      }
      
      // Get URLs from file_urls table
      try {
        final submissionDbUrl = await FileUrlService.getValidFileUrl(submissionId, 'submission');
        final assignmentDbUrl = await FileUrlService.getValidFileUrl(assignmentId, 'assignment');
        
        urlTests.add({
          'url': submissionDbUrl ?? 'null',
          'status': 'From DB',
          'type': 'submission_db',
          'works': submissionDbUrl != null && submissionDbUrl.isNotEmpty
        });
        
        urlTests.add({
          'url': assignmentDbUrl ?? 'null',
          'status': 'From DB',
          'type': 'assignment_db',
          'works': assignmentDbUrl != null && assignmentDbUrl.isNotEmpty
        });
      } catch (e) {
        print('Error getting URLs from file_urls table: $e');
      }
      
      // Close loading dialog
      Navigator.pop(context);
      
      // Show dialog with results
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('File URL Debug Results'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Submission ID: $submissionId'),
                Text('Assignment ID: $assignmentId'),
                Divider(),
                Text('Raw Paths:'),
                Text('- Submission: $submissionFileUrl'),
                Text('- Assignment: $assignmentFileUrl'),
                Divider(),
                Text('URL Tests:'),
                ...urlTests.map((test) => Container(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: test['works'] ? Colors.green : Colors.red,
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Type: ${test['type']}'),
                      Text('URL: ${test['url']}'),
                      Text('Status: ${test['status']}'),
                      Text('Works: ${test['works']}'),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                // Force update file URLs
                FileUrlService.migrateExistingFiles();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Started URL migration in background'))
                );
              },
              child: Text('Fix URLs'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Close loading dialog if open
      Navigator.pop(context);
      
      print('Error in debug function: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error debugging file URLs: $e')),
      );
    }
  }

  // Show dialog to grade submission manually
  void _showGradeDialog(Map<String, dynamic> submission, String assignmentTitle) {
    final TextEditingController pointsController = TextEditingController();
    final TextEditingController feedbackController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Grade Submission: $assignmentTitle'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student: ${submission['student_name']}', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              OutlinedButton.icon(
                icon: Icon(Icons.file_open),
                label: Text('Open Submission'),
                onPressed: () {
                  _openSubmissionFile(submission['file_url']);
                },
              ),
              SizedBox(height: 20),
              Text('Points:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: pointsController,
                decoration: InputDecoration(
                  hintText: 'Enter points',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: 20),
              Text('Feedback:', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: feedbackController,
                decoration: InputDecoration(
                  hintText: 'Enter feedback for the student',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Validate input
              if (pointsController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter points')),
                );
                return;
              }
              
              final int points = int.parse(pointsController.text);
              final String feedback = feedbackController.text;
              
              // Close dialog
              Navigator.pop(context);
              
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                // Save feedback to database
                await SubmissionService.saveTeacherFeedback(
                  submissionId: submission['id'],
                  feedback: feedback,
                  points: points,
                  isFromAI: false,
                );
                
                // Close loading dialog if context is still mounted
                if (context.mounted) {
                  // Force close any open dialogs to prevent stuck state
                  while (Navigator.of(context, rootNavigator: true).canPop()) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Feedback saved successfully!')),
                  );
                  
                  // Show a success dialog that auto-closes after 2 seconds
                  showDialog(
                    context: context,
                    barrierDismissible: true,
                    builder: (BuildContext dialogContext) {
                      // Auto-close after 2 seconds
                      Future.delayed(Duration(seconds: 2), () {
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      });
                      
                      return AlertDialog(
                        backgroundColor: Colors.green[100],
                        title: Text('Success'),
                        content: Text('Feedback saved successfully!'),
                      );
                    },
                  );
                  
                  // Refresh the list with a slight delay to ensure UI updates properly
                  Future.delayed(Duration(milliseconds: 500), () {
                    if (mounted) _loadPendingSubmissions();
                  });
                }
              } catch (e) {
                // Close loading dialog if context is still mounted
                if (context.mounted) {
                  // Force close any open dialogs
                  while (Navigator.of(context, rootNavigator: true).canPop()) {
                    Navigator.of(context, rootNavigator: true).pop();
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving feedback: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: Text('Submit Grade'),
          ),
        ],
      ),
    );
  }

  Future<void> _openSubmissionFile(String filePath) async {
    try {
      if (filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No submission file available')),
        );
        return;
      }
      
      print('Opening submission file path: $filePath');
      
      // Get full URL
      final fullUrl = SubmissionService.getFullUrl('submissions', filePath);
      print('Full URL: $fullUrl');
      
      // Launch URL in browser
      if (!await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open submission file')),
        );
      }
    } catch (e) {
      print('Error opening submission file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  Future<void> _openAssignmentFile(String filePath) async {
    try {
      if (filePath.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No assignment file available')),
        );
        return;
      }
      
      print('Opening assignment file path: $filePath');
      
      // Get full URL
      final fullUrl = SubmissionService.getFullUrl('assignments', filePath);
      print('Full URL: $fullUrl');
      
      // Launch URL in browser
      if (!await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open assignment file')),
        );
      }
    } catch (e) {
      print('Error opening assignment file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening file: $e')),
      );
    }
  }

  // Add this method to load assignments for the teacher
  Future<List<Map<String, dynamic>>> _loadAssignmentsForTeacher() async {
    try {
      final user = await supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No user found');
      }
      
      // Get assignments
      final assignments = await supabase
          .from('assignments')
          .select('*, classes:class_id(name)')
          .eq('teacher_id', user.id)
          .order('created_at', ascending: false);
          
      // Format the assignments
      return assignments.map<Map<String, dynamic>>((assignment) {
        return {
          ...assignment,
          'class_name': assignment['classes'] != null ? assignment['classes']['name'] : 'Unknown Class',
        };
      }).toList();
    } catch (e) {
      print('Error loading assignments: $e');
      throw e;
    }
  }
}