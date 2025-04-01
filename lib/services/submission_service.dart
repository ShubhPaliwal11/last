import '../utils/supabase_config.dart';
import '../models/submission_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/file_url_service.dart';

class SubmissionService {
  static Future<SubmissionModel> submitAssignment({
    required String assignmentId,
    required String studentId,
    String? fileUrl,
    String? comment,
  }) async {
    try {
      print('Submitting assignment: $assignmentId for student: $studentId');
      print('File URL: $fileUrl');
      
      // Make sure the file URL is a complete URL
      String? processedFileUrl = fileUrl;
      if (fileUrl != null && fileUrl.isNotEmpty && !fileUrl.startsWith('http')) {
        // If it's a path and not a URL, convert it
        processedFileUrl = supabase.storage.from('submissions').getPublicUrl(fileUrl);
        print('Processed file URL: $processedFileUrl');
      }
      
      // Only include fields that exist in the database schema
      final response = await supabase.from('submissions').insert({
        'student_id': studentId,
        'assignment_id': assignmentId,
        'file_url': processedFileUrl,
        'submitted_at': DateTime.now().toIso8601String(),
        'status': 'pending',
        'ai_generated': false,
      }).select();
      
      // If you want to store the comment, you would need a separate table or column
      // For now, we'll just log it
      if (comment != null && comment.isNotEmpty) {
        print('Comment provided but not stored in DB (column missing): $comment');
      }
      
      print('Submission created: ${response.first['id']}');
      return SubmissionModel.fromJson(response.first);
    } catch (e) {
      print('Error in submitAssignment: $e');
      throw e;
    }
  }

  static Future<SubmissionModel?> getSubmission(String assignmentId, String studentId) async {
    final response = await supabase
        .from('submissions')
        .select()
        .eq('assignment_id', assignmentId)
        .eq('student_id', studentId)
        .maybeSingle();
    
    if (response == null) return null;
    return SubmissionModel.fromJson(response);
  }

  static Future<List<SubmissionModel>> getAssignmentSubmissions(String assignmentId) async {
    final response = await supabase
        .from('submissions')
        .select()
        .eq('assignment_id', assignmentId)
        .order('submitted_at', ascending: false);
    
    return response.map<SubmissionModel>((json) => SubmissionModel.fromJson(json)).toList();
  }

  static Future<void> gradeSubmission({
    required String submissionId,
    required int points,
    String? feedback,
  }) async {
    await supabase.from('submissions').update({
      'points': points,
      'feedback': feedback,
      'graded_at': DateTime.now().toIso8601String(),
      'status': 'reviewed',
    }).eq('id', submissionId);
    
    // Also update the feedback table
    if (feedback != null && feedback.isNotEmpty) {
      await supabase.from('feedback').insert({
        'submission_id': submissionId,
        'content': feedback,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingSubmissionsForTeacher(String teacherId) async {
    try {
      print('Getting pending submissions for teacher: $teacherId');
      
      // Get all assignments created by this teacher
      final assignmentsResponse = await supabase
          .from('assignments')
          .select('id, title, class_id')
          .eq('teacher_id', teacherId);
      
      print('Found ${assignmentsResponse.length} assignments for teacher');
      
      if (assignmentsResponse.isEmpty) {
        print('No assignments found, returning empty list');
        return [];
      }
      
      // Get all assignment IDs
      final assignmentIds = assignmentsResponse.map((assignment) => assignment['id']).toList();
      print('Assignment IDs: $assignmentIds');
      
      // Try a simpler approach - avoid using filter/in since that might be causing issues
      List<Map<String, dynamic>> submissionsWithDetails = [];
      
      // Process each assignment individually to avoid using filter/in
      for (var assignment in assignmentsResponse) {
        print('Checking submissions for assignment: ${assignment['id']} (${assignment['title']})');
        
        try {
          // Get ONLY pending submissions for this specific assignment
          final assignmentSubmissions = await supabase
              .from('submissions')
              .select('id, assignment_id, student_id, file_url, submitted_at, status')
              .eq('assignment_id', assignment['id'])
              .eq('status', 'pending'); // This ensures we only get pending submissions
              
          print('Found ${assignmentSubmissions.length} pending submissions for assignment ${assignment['title']}');
          
          // Process each submission
          for (var submission in assignmentSubmissions) {
            try {
              // Get student profile
              final studentProfile = await supabase
                  .from('profiles')
                  .select('name, email')
                  .eq('id', submission['student_id'])
                  .maybeSingle();
              
              if (studentProfile != null) {
                submissionsWithDetails.add({
                  ...submission,
                  'assignment_title': assignment['title'],
                  'class_id': assignment['class_id'],
                  'student_name': studentProfile['name'],
                  'student_email': studentProfile['email'],
                });
                
                print('Added submission for student: ${studentProfile['name']}');
              } else {
                // No profile found, use placeholder
                print('No profile found for student ${submission['student_id']}');
                
                // Add with placeholder profile info
                submissionsWithDetails.add({
                  ...submission,
                  'assignment_title': assignment['title'],
                  'class_id': assignment['class_id'],
                  'student_name': 'Unknown Student',
                  'student_email': 'unknown@example.com',
                });
              }
            } catch (profileError) {
              print('Error getting profile for student ${submission['student_id']}: $profileError');
              
              // Add with placeholder profile info
              submissionsWithDetails.add({
                ...submission,
                'assignment_title': assignment['title'],
                'class_id': assignment['class_id'],
                'student_name': 'Unknown Student',
                'student_email': 'unknown@example.com',
              });
            }
          }
        } catch (assignmentError) {
          print('Error processing assignment ${assignment['id']}: $assignmentError');
          // Continue to next assignment
        }
      }
      
      print('Total processed submissions: ${submissionsWithDetails.length}');
      return submissionsWithDetails;
    } catch (e) {
      print('Error in getPendingSubmissionsForTeacher: $e');
      // Return empty list instead of throwing, to prevent UI errors
      return [];
    }
  }

  // Helper function to get full URL from storage path
  static String getFullUrl(String bucket, String path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    
    final baseUrl = 'https://shrnxdbbaxfhjaxelbjl.supabase.co/storage/v1/object/public';
    String fullUrl = '$baseUrl/$bucket/$path';
    if (!fullUrl.toLowerCase().endsWith('.pdf')) fullUrl += '.pdf';
    return fullUrl;
  }

  static Future<String> getAIFeedback({
    required String assignmentTitle,
    required String assignmentDescription,
    required String studentName,
    required String submissionId,
    required String assignmentId,
  }) async {
    try {
      print('Preparing to analyze submission for: $studentName');
      print('Assignment: $assignmentTitle');
      
      // Get the submission file URL directly from the submissions table
      final submission = await supabase
          .from('submissions')
          .select('file_url')
          .eq('id', submissionId)
          .single();
          
      final submissionFilePath = submission['file_url'];
      if (submissionFilePath == null || submissionFilePath.isEmpty) {
        print('ERROR: No submission file URL found!');
        return 'Error: No submission file found to analyze. The student may not have uploaded a file.';
      }
      
      // Get the assignment file URL directly from the assignments table
      final assignment = await supabase
          .from('assignments')
          .select('file_url')
          .eq('id', assignmentId)
          .single();
          
      final assignmentFilePath = assignment['file_url'];
      
      // Convert to full URLs
      final submissionUrl = getFullUrl('submissions', submissionFilePath);
      final assignmentUrl = assignmentFilePath != null && assignmentFilePath.isNotEmpty 
          ? getFullUrl('assignments', assignmentFilePath) 
          : '';
      
      print('Submission URL: $submissionUrl');
      print('Assignment URL: $assignmentUrl');
      
      // Prepare the payload for Make.com
      final payload = {
        'assignmentTitle': assignmentTitle,
        'assignmentDescription': assignmentDescription,
        'studentName': studentName,
        'submissionPdfUrl': submissionUrl,
        'submissionPdfMimeType': 'application/pdf',
        // Only include assignment PDF if available
        if (assignmentUrl.isNotEmpty) 'assignmentPdfUrl': assignmentUrl,
        if (assignmentUrl.isNotEmpty) 'assignmentPdfMimeType': 'application/pdf',
        'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
        'hasAssignmentFile': assignmentUrl.isNotEmpty,
      };
      
      print('Sending submission for AI analysis with:');
      print('- Student submission URL: $submissionUrl');
      if (assignmentUrl.isNotEmpty) {
        print('- Assignment file URL: $assignmentUrl');
      } else {
        print('- No assignment file URL available');
      }
      
      // Make.com webhook URL provided by the user
      final makeWebhookUrl = 'https://hook.eu2.make.com/jku6pwlpbfh349x2jq1mnds2qebx4ruu';
      
      // Send request to Make.com
      final response = await http.post(
        Uri.parse(makeWebhookUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      );
      
      // Process response
      if (response.statusCode == 200) {
        print('Received response from Make.com');
        print('Response length: ${response.body.length} characters');
        
        // First try the standard JSON parse approach
        try {
          // Sanitize any control characters in the response that might break JSON parsing
          String sanitizedResponse = _sanitizeJsonString(response.body);
          final data = jsonDecode(sanitizedResponse);
          
          // The response should contain a 'feedback' field
          if (data.containsKey('feedback')) {
            String feedback = data['feedback']?.toString() ?? '';
            print('Successfully parsed JSON response with feedback of ${feedback.length} characters');
            if (feedback.isEmpty) {
              return 'No feedback was generated. Please try again or review the submission manually.';
            }
            return feedback;
          } else {
            print('Make.com response did not contain feedback field.');
          }
        } catch (parseError) {
          print('Error parsing Make.com response as JSON: $parseError');
        }
        
        // If JSON parsing failed, try a direct approach to extract the feedback
        print('Attempting alternative extraction method');
        String responseBody = response.body;
        
        // Look for feedback field in the response
        if (responseBody.contains('"feedback"')) {
          try {
            // Try to extract the full feedback text using regex for more reliable extraction
            // This regex will find the content of the "feedback" field, handling multiline content and escaped quotes
            RegExp feedbackRegex = RegExp(r'"feedback"\s*:\s*"((?:.|\n|\r)*?)(?<!\\)"(?=,|\s*})', dotAll: true);
            var match = feedbackRegex.firstMatch(responseBody);
            
            if (match != null && match.groupCount >= 1) {
              String extractedFeedback = match.group(1) ?? '';
              print('Raw extracted feedback length: ${extractedFeedback.length}');
              
              // Unescape the string
              extractedFeedback = extractedFeedback
                  .replaceAll('\\"', '"')
                  .replaceAll('\\n', '\n')
                  .replaceAll('\\r', '\r')
                  .replaceAll('\\t', '\t')
                  .replaceAll('\\\\', '\\');
                  
              print('Extracted feedback using regex: ${extractedFeedback.length} characters');
              print('First 50 chars: ${extractedFeedback.substring(0, math.min(50, extractedFeedback.length))}');
              print('Last 50 chars: ${extractedFeedback.substring(math.max(0, extractedFeedback.length - 50))}');
              return extractedFeedback;
            } else {
              print('Regex match failed - could not find feedback pattern in response');
            }
          } catch (e) {
            print('Error extracting feedback with alternative methods: $e');
          }
        }
        
        // If regex fails, try the manual extraction method
        print('Trying manual extraction as fallback');
        int startIndex = responseBody.indexOf('"feedback"');
        if (startIndex >= 0) {
          startIndex += 11; // Move past '"feedback":'
          
          // Find opening quote
          while (startIndex < responseBody.length && responseBody[startIndex] != '"') {
            startIndex++;
          }
          startIndex++; // Move past opening quote
          
          // Find closing quote (accounting for escaped quotes)
          int endIndex = startIndex;
          bool escaped = false;
          int braces = 0;
          
          // Try to find the end of the JSON string by looking for an unescaped quote
          // followed by either a comma or closing brace
          while (endIndex < responseBody.length) {
            if (responseBody[endIndex] == '\\') {
              escaped = !escaped;
              endIndex++;
            } else if (responseBody[endIndex] == '"' && !escaped) {
              // Check if this is followed by a comma or closing brace
              int nextPos = endIndex + 1;
              while (nextPos < responseBody.length && 
                     (responseBody[nextPos] == ' ' || responseBody[nextPos] == '\n' || 
                      responseBody[nextPos] == '\r' || responseBody[nextPos] == '\t')) {
                nextPos++; // Skip whitespace
              }
              
              if (nextPos < responseBody.length && 
                  (responseBody[nextPos] == ',' || responseBody[nextPos] == '}')) {
                break; // This is the end of the JSON string
              }
              endIndex++;
            } else {
              escaped = false;
              endIndex++;
            }
          }
          
          if (endIndex > startIndex) {
            String extractedFeedback = responseBody.substring(startIndex, endIndex);
            print('Raw manually extracted feedback length: ${extractedFeedback.length}');
            
            // Unescape the string
            extractedFeedback = extractedFeedback
                .replaceAll('\\"', '"')
                .replaceAll('\\n', '\n')
                .replaceAll('\\r', '\r')
                .replaceAll('\\t', '\t')
                .replaceAll('\\\\', '\\');
                
            print('Extracted feedback manually: ${extractedFeedback.length} characters');
            print('First 50 chars: ${extractedFeedback.substring(0, math.min(50, extractedFeedback.length))}');
            print('Last 50 chars: ${extractedFeedback.substring(math.max(0, extractedFeedback.length - 50))}');
            return extractedFeedback;
          }
        }
        
        // Last resort - just return raw response in a formatted way
        print('All extraction methods failed. Returning raw response.');
        
        // Clean the response for display
        String cleanedResponse = response.body
            .replaceAll(RegExp(r'[^\x20-\x7E\n\r\t]'), '') // Keep only printable ASCII and newlines
            .trim();
            
        if (cleanedResponse.length > 100) {
            return 'The AI service response could not be properly processed.\n\nRaw response excerpt:\n${cleanedResponse.substring(0, 100)}...\n\nPlease try again or review the submission manually.';
        } else {
            return 'The AI service response could not be properly processed. Please try again or review the submission manually.';
        }
      } else {
        print('Error from Make.com: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to generate AI feedback: ${response.statusCode}');
      }
    } catch (e) {
      print('Error getting AI feedback: $e');
      return 'An error occurred while analyzing the submission: $e\n\nPlease try again later or review the submission manually.';
    }
  }

  // Helper method to sanitize JSON strings by removing or escaping control characters
  static String _sanitizeJsonString(String input) {
    if (input == null || input.isEmpty) return '';
    
    // Replace control characters that break JSON
    String sanitized = input
      .replaceAll('\u0000', '') // null character
      .replaceAll('\u0001', '')
      .replaceAll('\u0002', '')
      .replaceAll('\u0003', '')
      .replaceAll('\u0004', '')
      .replaceAll('\u0005', '')
      .replaceAll('\u0006', '')
      .replaceAll('\u0007', '')
      .replaceAll('\u0008', '')
      .replaceAll('\u000B', '')
      .replaceAll('\u000C', '')
      .replaceAll('\u000E', '')
      .replaceAll('\u000F', '')
      .replaceAll('\u0010', '')
      .replaceAll('\u0011', '')
      .replaceAll('\u0012', '')
      .replaceAll('\u0013', '')
      .replaceAll('\u0014', '')
      .replaceAll('\u0015', '')
      .replaceAll('\u0016', '')
      .replaceAll('\u0017', '')
      .replaceAll('\u0018', '')
      .replaceAll('\u0019', '')
      .replaceAll('\u001A', '')
      .replaceAll('\u001B', '')
      .replaceAll('\u001C', '')
      .replaceAll('\u001D', '')
      .replaceAll('\u001E', '')
      .replaceAll('\u001F', '');
    
    // Properly escape characters that should be escaped
    sanitized = sanitized
      .replaceAll('\n', '\\n')
      .replaceAll('\r', '\\r')
      .replaceAll('\t', '\\t')
      .replaceAll('"', '\\"');
      
    return sanitized;
  }

  // Add a method to save feedback and update submission status with retry
  static Future<void> saveTeacherFeedback({
    required String submissionId,
    required String feedback,
    required bool isFromAI,
    int? points,
  }) async {
    print('saveTeacherFeedback called for submission: $submissionId');
    print('Feedback length: ${feedback.length}, isFromAI: $isFromAI, points: $points');
    
    try {
      // First get the assignment and student details from the submission
      print('Fetching submission details...');
      final submission = await supabase
          .from('submissions')
          .select('assignment_id, student_id')
          .eq('id', submissionId)
          .single();
          
      final assignmentId = submission['assignment_id'];
      final studentId = submission['student_id'];
      
      print('Got assignment_id: $assignmentId, student_id: $studentId');
      
      // Get teacher ID
      print('Getting current user...');
      final user = await supabase.auth.currentUser;
      if (user == null) {
        print('Error: User not authenticated');
        throw Exception('User not authenticated');
      }
      
      print('Current user ID: ${user.id}');
      
      // Update the submission status to 'reviewed'
      print('Updating submission status to reviewed...');
      try {
        // First verify we can access the submission
        final submissionCheck = await supabase
            .from('submissions')
            .select('*')
            .eq('id', submissionId)
            .single();
        print('Current submission state:');
        print('- Status: ${submissionCheck['status']}');
        print('- Points: ${submissionCheck['points']}');
        print('- AI Generated: ${submissionCheck['ai_generated']}');
        
        // Update submission status, points, and reviewed_at timestamp
        final now = DateTime.now().toIso8601String();
        final updateResponse = await supabase
            .from('submissions')
            .update({
              'status': 'reviewed',
              'ai_generated': isFromAI,
              'points': points,
              'reviewed_at': now,
            })
            .eq('id', submissionId)
            .select() // Add select() to get the response data
            .single();
        
        print('Update response received:');
        print(updateResponse);
        
        // Short delay to ensure database consistency
        await Future.delayed(Duration(milliseconds: 500));
        
        // Verify the update with more detailed logging
        print('Verifying update...');
        final updatedSubmission = await supabase
            .from('submissions')
            .select('*')
            .eq('id', submissionId)
            .single();
            
        print('Verification results:');
        print('- Status: ${updatedSubmission['status']}');
        print('- Points: ${updatedSubmission['points']}');
        print('- Reviewed At: ${updatedSubmission['reviewed_at']}');
        print('- AI Generated: ${updatedSubmission['ai_generated']}');
        
        // More lenient verification that checks each field separately
        List<String> verificationErrors = [];
        
        if (updatedSubmission['status'] != 'reviewed') {
            verificationErrors.add('Status not updated to reviewed (current: ${updatedSubmission['status']})');
        }
        if (updatedSubmission['points']?.toString() != points?.toString()) {
            verificationErrors.add('Points not updated correctly (expected: $points, got: ${updatedSubmission['points']})');
        }
        if (updatedSubmission['reviewed_at'] == null) {
            verificationErrors.add('Review timestamp not set');
        }
        if (updatedSubmission['ai_generated'] != isFromAI) {
            verificationErrors.add('AI generation flag not set correctly (expected: $isFromAI, got: ${updatedSubmission['ai_generated']})');
        }
        
        if (verificationErrors.isNotEmpty) {
            print('Verification errors found: ${verificationErrors.join(', ')}');
            throw Exception('Status update verification failed: ${verificationErrors.join(', ')}');
        }
        
        print('Status update verified successfully');
        
      } catch (updateError) {
        print('Error updating submission status: $updateError');
        if (updateError is PostgrestException) {
            print('Postgrest error code: ${updateError.code}');
            print('Postgrest error message: ${updateError.message}');
            print('Postgrest error details: ${updateError.details}');
            print('Postgrest error hint: ${updateError.hint}');
        }
        throw Exception('Failed to update submission status: $updateError');
      }
      
      String processedFeedback = feedback;
      
      // Check if there's already feedback for this submission from this teacher
      print('Checking for existing feedback...');
      try {
        // First count how many matching records exist
        final countResponse = await supabase
            .from('feedback')
            .select()
            .eq('submission_id', submissionId)
            .eq('teacher_id', user.id);
            
        final int recordCount = countResponse.length;
        print('Found $recordCount existing feedback records');
        
        if (recordCount > 0) {
          // If there are existing records, delete them (to avoid having multiple)
          print('Deleting existing feedback records to avoid duplicates');
          try {
            // Delete one by one to ensure they are all removed
            for (final record in countResponse) {
              await supabase
                .from('feedback')
                .delete()
                .eq('id', record['id']);
              print('Deleted feedback record ID: ${record['id']}');
            }
            print('Deleted all existing feedback records');
          } catch (deleteError) {
            print('Error deleting feedback records: $deleteError');
            // Continue with insert anyway
          }
        }
        
        // Now insert the new feedback
        final feedbackData = {
          'submission_id': submissionId,
          'teacher_id': user.id,
          'student_id': studentId,
          'assignment_id': assignmentId,
          'feedback_text': processedFeedback,
          'created_at': DateTime.now().toIso8601String(),
          'is_ai': isFromAI,
          // Don't include points in feedback table as it doesn't exist
        };
        
        print('Inserting new feedback record');
        await supabase.from('feedback').insert(feedbackData);
        print('Feedback inserted successfully');
        
        return; // Success!
      } catch (feedbackError) {
        print('Error handling feedback: $feedbackError');
        
        // If the feedback might be too long, try with truncated version
        if (processedFeedback.length > 30000) {
          print('Trying with truncated feedback (30000 chars)...');
          try {
            await supabase.from('feedback').insert({
              'submission_id': submissionId,
              'teacher_id': user.id,
              'student_id': studentId,
              'assignment_id': assignmentId,
              'feedback_text': processedFeedback.substring(0, 30000),
              'created_at': DateTime.now().toIso8601String(),
              'is_ai': isFromAI,
              // Don't include points
            });
            print('Truncated feedback inserted successfully');
            return; // Success with truncated feedback
          } catch (truncateError) {
            print('Error inserting truncated feedback: $truncateError');
            // Continue to retry with alternative approach
          }
        } else {
          // Re-throw original error if truncation wasn't needed
          throw feedbackError;
        }
      }
    } catch (e) {
      print('Error in saveTeacherFeedback: $e');
      throw e; // Rethrow to propagate to caller
    }
  }

  // Get feedback for a student's submission
  static Future<Map<String, dynamic>?> getSubmissionFeedback(String submissionId) async {
    try {
      print('Getting feedback for submission: $submissionId');
      
      // Get feedback from the feedback table
      final feedbackResponse = await supabase
          .from('feedback')
          .select('*, profiles:teacher_id(name)')
          .eq('submission_id', submissionId)
          .order('created_at', ascending: false)
          .limit(1) // Limit to most recent feedback
          .maybeSingle();
      
      if (feedbackResponse == null) {
        print('No feedback found for submission $submissionId');
        return null;
      }
      
      print('Found feedback with ID: ${feedbackResponse['id']}');
      final feedbackLength = feedbackResponse['feedback_text']?.toString().length ?? 0;
      print('Feedback text length: $feedbackLength characters');
      
      if (feedbackLength == 0) {
        print('WARNING: Feedback text is empty!');
      } else if (feedbackLength < 100) {
        print('WARNING: Feedback text is unusually short: $feedbackLength chars');
        print('Feedback preview: ${feedbackResponse['feedback_text']}');
      }
      
      // Get submission details
      final submissionResponse = await supabase
          .from('submissions')
          .select('*, assignments(title, max_points)')
          .eq('id', submissionId)
          .single();
      
      // Extract the feedback text carefully to avoid null issues
      String feedbackText = '';
      if (feedbackResponse.containsKey('feedback_text') && 
          feedbackResponse['feedback_text'] != null) {
        feedbackText = feedbackResponse['feedback_text'].toString();
      }
      
      // Check if feedback might be truncated
      bool mightBeTruncated = false;
      if (feedbackText.endsWith('[ERROR: The complete feedback was too large to store. Please ask your teacher for the full version.]')) {
        mightBeTruncated = true;
        print('Feedback appears to be truncated');
      }
      
      // Combine the data
      final result = {
        'feedback': feedbackText,
        'feedback_text': feedbackText,
        'is_ai': feedbackResponse['is_ai'] ?? false,
        'teacher_name': feedbackResponse['profiles'] != null 
            ? feedbackResponse['profiles']['name'] 
            : 'Teacher',
        'created_at': feedbackResponse['created_at'],
        'submission_status': submissionResponse['status'],
        'submitted_at': submissionResponse['submitted_at'],
        'assignment_title': submissionResponse['assignments']['title'],
        'max_points': submissionResponse['assignments']['max_points'],
        'might_be_truncated': mightBeTruncated,
      };
      
      print('Prepared feedback result with ${result['feedback']?.toString().length ?? 0} characters');
      
      // Verify content is not empty
      if ((result['feedback']?.toString().isEmpty ?? true) &&
          (result['feedback_text']?.toString().isEmpty ?? true)) {
        print('WARNING: Result feedback is empty! Check database content.');
      }
      
      return result;
    } catch (e) {
      print('Error getting submission feedback: $e');
      return null;
    }
  }

  static Future<String?> uploadSubmissionFile(String studentId, String assignmentId) async {
    try {
      final user = await supabase.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      
      print('Uploading submission file for student: $studentId');
      
      // Attempt to create the submissions bucket if it doesn't exist
      try {
        // First check if the bucket already exists
        final buckets = await supabase.storage.listBuckets();
        bool bucketExists = buckets.any((bucket) => bucket.name == 'submissions');
        
        if (!bucketExists) {
          print('Creating submissions bucket');
          await supabase.storage.createBucket('submissions');
          
          // Try to set bucket to public
          try {
            await supabase.storage.updateBucket(
              'submissions',
              const BucketOptions(public: true),
            );
            print('Set submissions bucket to public');
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
        print('Using file picker approach for submission upload');
        
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
        
        // Create a unique file name with student ID and timestamp
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'student_${studentId}/${timestamp}_$cleanFileName';
        
        print('Final file name for storage: $fileName');
        
        // Upload using Uint8List (works on web)
        await supabase.storage
            .from('submissions')
            .uploadBinary(fileName, fileBytes);
        
        print('Successfully uploaded submission file to: $fileName');
        
        return fileName; // Return the storage path
      } catch (uploadError) {
        print('Error during submission upload: $uploadError');
        throw uploadError;
      }
    } catch (e) {
      print('Error handling submission file upload: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getReviewedSubmissionsForTeacher(String teacherId) async {
    try {
      print('Getting reviewed submissions for teacher: $teacherId');
      
      // Get all assignments created by this teacher
      final assignmentsResponse = await supabase
          .from('assignments')
          .select('id, title, class_id')
          .eq('teacher_id', teacherId);
      
      print('Found ${assignmentsResponse.length} assignments for teacher');
      
      if (assignmentsResponse.isEmpty) {
        print('No assignments found, returning empty list');
        return [];
      }
      
      List<Map<String, dynamic>> submissionsWithDetails = [];
      
      // Process each assignment individually
      for (var assignment in assignmentsResponse) {
        print('Checking reviewed submissions for assignment: ${assignment['id']} (${assignment['title']})');
        
        try {
          // Get ONLY reviewed submissions for this specific assignment
          final assignmentSubmissions = await supabase
              .from('submissions')
              .select('id, assignment_id, student_id, file_url, submitted_at, status, points, reviewed_at')
              .eq('assignment_id', assignment['id'])
              .eq('status', 'reviewed')
              .order('reviewed_at', ascending: false); // Most recently reviewed first
              
          print('Found ${assignmentSubmissions.length} reviewed submissions for assignment ${assignment['title']}');
          
          // Process each submission
          for (var submission in assignmentSubmissions) {
            try {
              // Get student profile
              final studentProfile = await supabase
                  .from('profiles')
                  .select('name, email')
                  .eq('id', submission['student_id'])
                  .maybeSingle();
              
              // Get feedback
              final feedback = await supabase
                  .from('feedback')
                  .select('feedback_text, created_at, is_ai')
                  .eq('submission_id', submission['id'])
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle();
              
              if (studentProfile != null) {
                submissionsWithDetails.add({
                  ...submission,
                  'assignment_title': assignment['title'],
                  'class_id': assignment['class_id'],
                  'student_name': studentProfile['name'],
                  'student_email': studentProfile['email'],
                  'feedback_text': feedback?['feedback_text'],
                  'feedback_created_at': feedback?['created_at'],
                  'is_ai_feedback': feedback?['is_ai'] ?? false,
                });
                
                print('Added reviewed submission for student: ${studentProfile['name']}');
              } else {
                // No profile found, use placeholder
                print('No profile found for student ${submission['student_id']}');
                submissionsWithDetails.add({
                  ...submission,
                  'assignment_title': assignment['title'],
                  'class_id': assignment['class_id'],
                  'student_name': 'Unknown Student',
                  'student_email': 'unknown@example.com',
                  'feedback_text': feedback?['feedback_text'],
                  'feedback_created_at': feedback?['created_at'],
                  'is_ai_feedback': feedback?['is_ai'] ?? false,
                });
              }
            } catch (profileError) {
              print('Error getting profile for student ${submission['student_id']}: $profileError');
              submissionsWithDetails.add({
                ...submission,
                'assignment_title': assignment['title'],
                'class_id': assignment['class_id'],
                'student_name': 'Unknown Student',
                'student_email': 'unknown@example.com',
              });
            }
          }
        } catch (assignmentError) {
          print('Error processing assignment ${assignment['id']}: $assignmentError');
          // Continue to next assignment
        }
      }
      
      print('Total processed reviewed submissions: ${submissionsWithDetails.length}');
      return submissionsWithDetails;
    } catch (e) {
      print('Error in getReviewedSubmissionsForTeacher: $e');
      return [];
    }
  }
} 