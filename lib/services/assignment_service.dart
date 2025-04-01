import '../utils/supabase_config.dart';
import '../models/assignment_model.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class AssignmentService {
  static Future<List<AssignmentModel>> getClassAssignments(String classId) async {
    final response = await supabase
        .from('assignments')
        .select()
        .eq('class_id', classId)
        .order('created_at', ascending: false);
    
    return response.map<AssignmentModel>((json) => AssignmentModel.fromJson(json)).toList();
  }

  static Future<List<AssignmentModel>> getStudentAssignments(String studentId) async {
    // First get all classes the student is enrolled in
    final enrollmentsResponse = await supabase
        .from('enrollments')
        .select('class_id')
        .eq('student_id', studentId);
    
    final classIds = enrollmentsResponse.map<String>((json) => json['class_id'].toString()).toList();
    
    if (classIds.isEmpty) return [];
    
    // Get all assignments for these classes
    final assignmentsResponse = await supabase
        .from('assignments')
        .select()
        .filter('class_id', 'in', classIds)
        .order('due_date', ascending: true);
    
    return assignmentsResponse.map<AssignmentModel>((json) => AssignmentModel.fromJson(json)).toList();
  }

  static Future<List<AssignmentModel>> getDueAssignments(String studentId) async {
    try {
      final assignments = await getStudentAssignments(studentId);
      final now = DateTime.now();
      
      // Show all assignments that are:
      // 1. Due in the future (not overdue)
      // 2. Or are overdue but not submitted yet (need to check submissions)
      final filteredAssignments = assignments.where((assignment) {
        // Get assignments due within the next 14 days or recently overdue (within 7 days)
        final daysUntilDue = assignment.dueDate.difference(now).inDays;
        final daysOverdue = now.difference(assignment.dueDate).inDays;
        
        return (daysUntilDue >= 0 && daysUntilDue <= 14) || // Due soon
               (daysOverdue >= 0 && daysOverdue <= 7);      // Recently overdue
      }).toList();
      
      return filteredAssignments;
    } catch (e) {
      print('Error in getDueAssignments: $e');
      return [];
    }
  }

  static Future<void> createAssignment({
    required String title,
    required String description,
    required String teacherId,
    required DateTime dueDate,
    required String classId,
    int? maxPoints,
    String? fileUrl,
  }) async {
    try {
      print('Creating assignment with title: $title');
      print('Assignment file URL: $fileUrl');
      
      // Validate file URL if provided
      String? validatedFileUrl = fileUrl;
      if (fileUrl != null && fileUrl.isEmpty) {
        validatedFileUrl = null; // Convert empty string to null
        print('Empty file URL converted to null');
      }
      
      final data = {
        'title': title,
        'description': description,
        'teacher_id': teacherId,
        'class_id': classId,
        'due_date': dueDate.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'file_url': validatedFileUrl, // Use validated URL
      };
      
      // Add maxPoints if specified - convert to String to match database schema
      if (maxPoints != null) {
        data['max_points'] = maxPoints.toString();
      }
      
      // Insert the assignment
      await supabase.from('assignments').insert(data);
      print('Assignment created successfully');
    } catch (e) {
      print('Error creating assignment: $e');
      throw e;
    }
  }

  static Future<int> getAssignmentDueCount(String classId) async {
    final now = DateTime.now();
    
    final response = await supabase
        .from('assignments')
        .select()
        .eq('class_id', classId)
        .gte('due_date', now.toIso8601String());
    
    return response.length;
  }

  static Future<String?> uploadAssignmentFile(String className, String teacherId) async {
    try {
      final user = await supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      // Attempt to create the assignments bucket if it doesn't exist
      try {
        // First check if the bucket already exists
        final buckets = await supabase.storage.listBuckets();
        bool bucketExists = buckets.any((bucket) => bucket.name == 'assignments');
        
        if (!bucketExists) {
          print('Creating assignments bucket');
          await supabase.storage.createBucket('assignments');
          
          // Try to set bucket to public
          try {
            await supabase.storage.updateBucket(
              'assignments',
              const BucketOptions(public: true),
            );
            print('Set assignments bucket to public');
          } catch (updateError) {
            print('Error setting bucket to public: $updateError');
            // Continue anyway, as this is not critical
          }
        }
      } catch (e) {
        print('Error handling bucket: $e');
        // Continue anyway, as the bucket might already exist
      }
      
      // Use FilePicker to get file bytes (works on web and mobile)
      try {
        print('Using file picker approach for assignment upload');
        
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
          withData: true, // Important: get the file bytes
        );
        
        if (result == null || result.files.isEmpty || result.files.first.bytes == null) {
          throw Exception('No file selected or file data is empty');
        }
        
        final fileBytes = result.files.first.bytes!;
        final originalFileName = result.files.first.name;
        
        print('Original file name: $originalFileName');
        
        // Ensure the file name is not empty and ends with .pdf
        String cleanFileName = originalFileName.isNotEmpty ? originalFileName : 'document.pdf';
        if (!cleanFileName.toLowerCase().endsWith('.pdf')) {
          cleanFileName += '.pdf';
        }
        
        // Create a unique file name with teacher ID and timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'teacher_${teacherId}/${timestamp}_$cleanFileName';
        
        print('Final file name for storage: $fileName');
        
        // Upload using Uint8List (works on web)
        await supabase.storage
            .from('assignments')
            .uploadBinary(fileName, fileBytes);
        
        print('Successfully uploaded assignment file to: $fileName');
        
        // Get the public URL - make sure we're using the complete path
        final fileUrl = supabase.storage
            .from('assignments')
            .getPublicUrl(fileName);
        
        print('File URL: $fileUrl');
        
        // Verify the URL is working
        try {
          final response = await http.head(Uri.parse(fileUrl));
          print('URL status code: ${response.statusCode}');
          if (response.statusCode >= 400) {
            print('Warning: URL might not be accessible');
          }
        } catch (e) {
          print('Error testing URL: $e');
        }
        
        return fileName; // Return just the path, not the full URL
      } catch (uploadError) {
        print('Error during assignment upload: $uploadError');
        throw uploadError;
      }
    } catch (e) {
      print('Error handling assignment file upload: $e');
      rethrow;
    }
  }

  static Future<void> updateAssignmentFile(String assignmentId, String fileUrl) async {
    try {
      print('Updating file URL for assignment ID: $assignmentId');
      print('New file URL: $fileUrl');
      
      if (fileUrl.isEmpty) {
        print('Warning: Empty file URL provided');
        return;
      }
      
      await supabase
          .from('assignments')
          .update({'file_url': fileUrl})
          .eq('id', assignmentId);
      
      print('Assignment file URL updated successfully');
    } catch (e) {
      print('Error updating assignment file URL: $e');
      throw e;
    }
  }

  // Method to check if an assignment has a file and upload one if missing
  static Future<void> ensureAssignmentHasFile(String assignmentId, String teacherId) async {
    try {
      // First check if the assignment already has a file
      final response = await supabase
          .from('assignments')
          .select('title, file_url')
          .eq('id', assignmentId)
          .single();
      
      final String title = response['title'] ?? 'Untitled';
      final String? existingFileUrl = response['file_url'];
      
      if (existingFileUrl != null && existingFileUrl.isNotEmpty) {
        print('Assignment "$title" already has a file: $existingFileUrl');
        return;
      }
      
      print('Assignment "$title" has no file. Prompting for upload...');
      
      // Here we would typically show a UI dialog to the user
      // For now, we'll just call the upload method directly
      final fileUrl = await uploadAssignmentFile('', teacherId);
      
      if (fileUrl != null && fileUrl.isNotEmpty) {
        await updateAssignmentFile(assignmentId, fileUrl);
        print('Successfully added file to assignment "$title"');
      }
    } catch (e) {
      print('Error ensuring assignment has file: $e');
      throw e;
    }
  }

  // Method to fix truncated URLs in the database
  static Future<void> fixTruncatedFileUrls() async {
    try {
      print('Starting to fix truncated URLs in the database');
      
      // Get all assignments
      final assignments = await supabase
          .from('assignments')
          .select('id, file_url')
          .not('file_url', 'is', null);
      
      print('Found ${assignments.length} assignments with file URLs to check');
      
      int fixedCount = 0;
      
      // Check each assignment
      for (var assignment in assignments) {
        final String id = assignment['id'];
        final String fileUrl = assignment['file_url'] ?? '';
        
        // Skip empty URLs
        if (fileUrl.isEmpty) continue;
        
        // Check if the URL ends with an underscore
        if (fileUrl.endsWith('_')) {
          print('Found truncated URL for assignment $id: $fileUrl');
          
          // Update with a valid filename
          final String fixedUrl = fileUrl + 'document.pdf';
          
          // Update in database
          await supabase
              .from('assignments')
              .update({'file_url': fixedUrl})
              .eq('id', id);
          
          print('Fixed URL: $fixedUrl');
          fixedCount++;
        } 
        // Check if it's missing the .pdf extension
        else if (!fileUrl.toLowerCase().endsWith('.pdf') && 
                !fileUrl.startsWith('http')) {
          print('URL missing extension for assignment $id: $fileUrl');
          
          // Update with .pdf extension
          final String fixedUrl = fileUrl + '.pdf';
          
          // Update in database
          await supabase
              .from('assignments')
              .update({'file_url': fixedUrl})
              .eq('id', id);
          
          print('Fixed URL: $fixedUrl');
          fixedCount++;
        }
      }
      
      print('Fixed $fixedCount assignment URLs');
    } catch (e) {
      print('Error fixing truncated URLs: $e');
      throw e;
    }
  }
} 