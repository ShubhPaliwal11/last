import 'package:http/http.dart' as http;
import '../utils/supabase_config.dart';
import 'dart:convert';

class FileUrlService {
  static const String SUPABASE_URL = 'https://shrnxdbbaxfhjaxelbjl.supabase.co';
  
  // Create the table SQL function for RPC
  static Future<void> runCreateTableSql() async {
    try {
      print('Running SQL to create file_urls table');
      
      // SQL to create the table via RPC
      await supabase.rpc('run_sql', params: {
        'query': '''
          CREATE TABLE IF NOT EXISTS file_urls (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            related_id UUID NOT NULL,
            type VARCHAR NOT NULL,
            complete_url TEXT NOT NULL,
            filename TEXT NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );
          
          CREATE INDEX IF NOT EXISTS idx_file_urls_related_id ON file_urls(related_id);
          CREATE INDEX IF NOT EXISTS idx_file_urls_type ON file_urls(type);
        '''
      });
      
      print('SQL executed successfully');
    } catch (e) {
      print('Error creating table with SQL: $e');
      throw e;
    }
  }
  
  // Create the file_urls table if it doesn't exist
  static Future<void> createFileUrlsTable() async {
    try {
      print('Checking if file_urls table exists...');
      
      // Try to query the table to see if it exists
      try {
        await supabase.from('file_urls').select('id').limit(1);
        print('file_urls table already exists');
        return;
      } catch (e) {
        print('file_urls table does not exist, creating it...');
        // Fall through to create the table
      }
      
      // Try using the direct SQL approach
      try {
        await runCreateTableSql();
        print('Successfully created file_urls table using SQL');
        return;
      } catch (sqlError) {
        print('Error using SQL to create table: $sqlError');
        print('Will try using the Supabase management API instead...');
      }
      
      // Fallback: Try to create using management API if available
      // This will depend on user permissions
      try {
        // Supabase API key should be stored in a constant or retrieved from environment
        // The client doesn't expose the key directly as supabase.supabaseKey
        final apiKey = const String.fromEnvironment('SUPABASE_ANON_KEY',
            defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNocm54ZGJiYXhmaGpheGVsYmpsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MDY3MjQyMzQsImV4cCI6MjAyMjMwMDIzNH0.qO6WoRJYqiP3qg-FBYPXkiMwNSL9zgQN8Ug1BSTX7E8');
        
        final response = await http.post(
          Uri.parse('https://shrnxdbbaxfhjaxelbjl.supabase.co/rest/v1/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${supabase.auth.currentSession?.accessToken}',
            'apikey': apiKey,
          },
          body: jsonEncode({
            'table': 'file_urls',
            'columns': [
              {
                'name': 'id',
                'type': 'uuid',
                'isPrimary': true,
                'isNullable': false,
                'defaultValue': 'uuid_generate_v4()'
              },
              {
                'name': 'related_id',
                'type': 'uuid',
                'isNullable': false
              },
              {
                'name': 'type',
                'type': 'varchar',
                'isNullable': false
              },
              {
                'name': 'complete_url',
                'type': 'text',
                'isNullable': false
              },
              {
                'name': 'filename',
                'type': 'text',
                'isNullable': false
              },
              {
                'name': 'created_at',
                'type': 'timestamp with time zone',
                'defaultValue': 'now()'
              },
              {
                'name': 'updated_at',
                'type': 'timestamp with time zone',
                'defaultValue': 'now()'
              }
            ]
          }),
        );
        
        if (response.statusCode < 300) {
          print('Successfully created file_urls table using management API');
        } else {
          print('Failed to create table using management API: ${response.body}');
          throw Exception('Could not create table: ${response.statusCode}');
        }
      } catch (apiError) {
        print('Error using management API: $apiError');
        
        // Final fallback: alert user to create table manually
        print('ATTENTION: Could not automatically create the file_urls table.');
        print('Please create it manually in your Supabase dashboard using SQL:');
        print('''
          CREATE TABLE file_urls (
            id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
            related_id UUID NOT NULL,
            type VARCHAR NOT NULL,
            complete_url TEXT NOT NULL,
            filename TEXT NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
          );
          
          CREATE INDEX idx_file_urls_related_id ON file_urls(related_id);
          CREATE INDEX idx_file_urls_type ON file_urls(type);
        ''');
        
        throw Exception('Could not create file_urls table automatically. Please create it manually.');
      }
    } catch (e) {
      print('Error creating file_urls table: $e');
      throw e;
    }
  }
  
  // Store a valid file URL in the file_urls table
  static Future<String> storeValidFileUrl({
    required String relatedId, 
    required String type, // 'assignment' or 'submission'
    required String storagePath, 
    required String originalFilename
  }) async {
    try {
      print('Storing valid file URL for $type ID: $relatedId');
      print('Storage path: $storagePath');
      print('Original filename: $originalFilename');
      
      // Generate complete URL with proper path and extension
      final bucket = type == 'assignment' ? 'assignments' : 'submissions';
      
      // Handle different path formats
      // First, clean the path to ensure we don't have double slashes or unusual characters
      String cleanPath = storagePath;
      // If the path already contains the full URL, extract just the path part
      if (cleanPath.contains('supabase.co')) {
        final uri = Uri.parse(cleanPath);
        // Extract just the path part after /object/public/{bucket}/
        final pathSegments = uri.pathSegments;
        // Find the bucket in the path
        int bucketIndex = pathSegments.indexWhere((segment) => segment == bucket);
        if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {
          cleanPath = pathSegments.sublist(bucketIndex + 1).join('/');
          print('Extracted path from URL: $cleanPath');
        }
      }
      
      // Construct URL
      String completeUrl = '$SUPABASE_URL/storage/v1/object/public/$bucket/$cleanPath';
      
      // Ensure filename has .pdf extension
      if (!originalFilename.toLowerCase().endsWith('.pdf')) {
        originalFilename += '.pdf';
      }
      
      // Ensure URL ends with .pdf
      if (!completeUrl.toLowerCase().endsWith('.pdf')) {
        completeUrl += '.pdf';
      }
      
      print('Generated complete URL: $completeUrl');
      
      // Try multiple URL variations to find the correct one
      List<String> urlVariations = [
        completeUrl,
        // Remove any double extensions like .pdf.pdf
        completeUrl.replaceAll('.pdf.pdf', '.pdf'),
        // Try without .pdf extension
        completeUrl.replaceAll('.pdf', ''),
        // Try with the bucket name directly included in the path
        '$SUPABASE_URL/storage/v1/object/public/$bucket/$cleanPath',
      ];
      
      // Test each URL variation
      String workingUrl = '';
      for (String urlToTest in urlVariations) {
        try {
          print('Testing URL: $urlToTest');
          final response = await http.head(Uri.parse(urlToTest));
          print('URL status: ${response.statusCode}');
          
          if (response.statusCode >= 200 && response.statusCode < 300) {
            print('Found working URL: $urlToTest');
            workingUrl = urlToTest;
            break;
          }
        } catch (e) {
          print('Error testing URL: $e');
        }
      }
      
      // If we found a working URL, use it, otherwise use our best guess
      final String finalUrl = workingUrl.isNotEmpty ? workingUrl : completeUrl;
      print('Final URL to use: $finalUrl');
      
      // Fix for duplicate entries: First delete any existing entries
      try {
        print('Checking for existing entries to clean up duplicates...');
        // Get all existing entries for this related_id and type
        final existingEntries = await supabase
            .from('file_urls')
            .select('id')
            .eq('related_id', relatedId)
            .eq('type', type);
        
        if (existingEntries.length > 0) {
          print('Found ${existingEntries.length} existing entries, cleaning up...');
          
          // Delete all existing entries to avoid duplicates
          await supabase
              .from('file_urls')
              .delete()
              .eq('related_id', relatedId)
              .eq('type', type);
          
          print('Deleted existing entries');
        } else {
          print('No existing entries found');
        }
      } catch (e) {
        print('Warning: Error checking for existing entries: $e');
        // Continue anyway, we'll try to insert a new record
      }
      
      // Now insert a new record
      print('Creating new file URL record');
      try {
        final result = await supabase
            .from('file_urls')
            .insert({
              'related_id': relatedId,
              'type': type,
              'complete_url': finalUrl,
              'filename': originalFilename,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();
        
        print('Successfully created file URL record with ID: ${result['id']}');
        return result['id'];
      } catch (insertError) {
        print('Error inserting file URL: $insertError');
        // Return the related_id as a fallback so the process can continue
        return relatedId;
      }
    } catch (e) {
      print('Error storing file URL: $e');
      // Return the related_id as a fallback
      return relatedId;
    }
  }
  
  // Retrieve a valid URL from the file_urls table
  static Future<String?> getValidFileUrl(String relatedId, String type) async {
    try {
      print('Getting valid file URL for $type ID: $relatedId');
      
      // Modified to handle multiple entries - get the most recent one by updated_at
      final results = await supabase
          .from('file_urls')
          .select('complete_url, updated_at')
          .eq('related_id', relatedId)
          .eq('type', type)
          .order('updated_at', ascending: false)
          .limit(1);  // Just get the latest one
      
      if (results == null || results.isEmpty) {
        print('No file URL found for $type ID: $relatedId');
        return null;
      }
      
      final String url = results[0]['complete_url'];
      print('Found file URL: $url');
      return url;
    } catch (e) {
      print('Error getting file URL: $e');
      
      // If there's an error, try a fallback approach by directly constructing the URL
      try {
        print('Trying fallback approach for $type ID: $relatedId');
        
        // Get the file_url directly from the source table
        final sourceTable = type == 'assignment' ? 'assignments' : 'submissions';
        final result = await supabase
            .from(sourceTable)
            .select('file_url')
            .eq('id', relatedId)
            .single();
        
        if (result != null && result['file_url'] != null && result['file_url'].isNotEmpty) {
          final String storagePath = result['file_url'];
          final bucket = type == 'assignment' ? 'assignments' : 'submissions';
          String url = '$SUPABASE_URL/storage/v1/object/public/$bucket/$storagePath';
          
          // Ensure URL ends with .pdf
          if (!url.toLowerCase().endsWith('.pdf')) {
            url += '.pdf';
          }
          
          print('Generated fallback URL: $url');
          return url;
        }
      } catch (fallbackError) {
        print('Fallback approach also failed: $fallbackError');
      }
      
      return null;
    }
  }
  
  // Migrate all existing assignments and submissions to the file_urls table
  static Future<void> migrateExistingFiles() async {
    try {
      print('Starting migration of existing files to file_urls table...');
      
      // Create the table if it doesn't exist
      await createFileUrlsTable();
      
      // Get all assignments with file URLs
      final assignments = await supabase
          .from('assignments')
          .select('id, file_url')
          .not('file_url', 'is', null);
      
      print('Found ${assignments.length} assignments with file URLs to migrate');
      
      // Migrate assignments
      int assignmentSuccess = 0;
      int assignmentFailed = 0;
      
      for (var assignment in assignments) {
        final String id = assignment['id'];
        final String fileUrl = assignment['file_url'] ?? '';
        
        if (fileUrl.isEmpty) continue;
        
        try {
          // Extract filename or use default
          String filename = 'assignment.pdf';
          if (fileUrl.contains('/')) {
            filename = fileUrl.split('/').last;
          }
          
          await storeValidFileUrl(
            relatedId: id,
            type: 'assignment',
            storagePath: fileUrl,
            originalFilename: filename,
          );
          
          assignmentSuccess++;
        } catch (e) {
          print('Error migrating assignment $id: $e');
          assignmentFailed++;
        }
      }
      
      // Get all submissions with file URLs
      final submissions = await supabase
          .from('submissions')
          .select('id, file_url')
          .not('file_url', 'is', null);
      
      print('Found ${submissions.length} submissions with file URLs to migrate');
      
      // Migrate submissions
      int submissionSuccess = 0;
      int submissionFailed = 0;
      
      for (var submission in submissions) {
        final String id = submission['id'];
        final String fileUrl = submission['file_url'] ?? '';
        
        if (fileUrl.isEmpty) continue;
        
        try {
          // Extract filename or use default
          String filename = 'submission.pdf';
          if (fileUrl.contains('/')) {
            filename = fileUrl.split('/').last;
          }
          
          await storeValidFileUrl(
            relatedId: id,
            type: 'submission',
            storagePath: fileUrl,
            originalFilename: filename,
          );
          
          submissionSuccess++;
        } catch (e) {
          print('Error migrating submission $id: $e');
          submissionFailed++;
        }
      }
      
      print('Migration complete:');
      print('- Assignments: $assignmentSuccess succeeded, $assignmentFailed failed');
      print('- Submissions: $submissionSuccess succeeded, $submissionFailed failed');
    } catch (e) {
      print('Error during file migration: $e');
      throw e;
    }
  }
} 