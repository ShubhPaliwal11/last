// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'pages/welcome.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/login.dart';
import 'pages/teacher_page.dart';
import 'pages/student_page.dart';
import 'services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'utils/supabase_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase
  await initSupabase();

  // Make sure the storage buckets are properly configured with public access
  try {
    final supabase = Supabase.instance.client;
    
    // Check if required buckets exist and are public
    await _ensureBucketExists(supabase, 'assignments', true);
    await _ensureBucketExists(supabase, 'submissions', true);
    
    print('Storage buckets verified successfully');
  } catch (e) {
    print('Error configuring storage buckets: $e');
  }

  runApp(MyApp());
}

// Helper function to make sure a bucket exists and has the right settings
Future<void> _ensureBucketExists(SupabaseClient supabase, String bucketName, bool isPublic) async {
  try {
    final buckets = await supabase.storage.listBuckets();
    final bucket = buckets.where((b) => b.name == bucketName).toList();
    
    if (bucket.isEmpty) {
      // Create bucket if it doesn't exist
      print('Creating bucket: $bucketName');
      // Just create the bucket - don't try to update settings for now
      await supabase.storage.createBucket(bucketName);
      print('Created bucket: $bucketName');
    } else {
      print('Bucket $bucketName already exists');
    }
    // Skip trying to update bucket permissions - would require proper BucketOptions
  } catch (e) {
    print('Error with bucket $bucketName: $e');
    // Just continue - admin will need to fix this manually
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EduAssist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Nexa',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
    
    // Listen for auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      
      if (event == AuthChangeEvent.signedIn) {
        _checkAuthState();
      } else if (event == AuthChangeEvent.signedOut) {
        setState(() {
          _isAuthenticated = false;
          _userRole = null;
        });
      }
    });
  }

  Future<void> _checkAuthState() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final user = await Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final role = await AuthService.getUserRole();
        setState(() {
          _isAuthenticated = true;
          _userRole = role;
        });
      } else {
        setState(() {
          _isAuthenticated = false;
          _userRole = null;
        });
      }
    } catch (e) {
      print('Error checking auth state: $e');
      setState(() {
        _isAuthenticated = false;
        _userRole = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    if (!_isAuthenticated) {
      return WelcomePage();
    }
    
    if (_userRole == 'teacher') {
      return TeacherHomePage();
    } else if (_userRole == 'student') {
      return StudentHomePage();
    } else {
      // Role not recognized, show login page
      return LoginPage();
    }
  }
}