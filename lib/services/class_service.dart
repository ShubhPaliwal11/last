import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/supabase_config.dart';
import '../models/class_model.dart';

class ClassService {
  static final List<Color> _classColors = [
    Colors.blue,
    Colors.green,
    Colors.purple,
    Colors.orange,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
    Colors.red,
    Colors.amber,
    Colors.cyan,
  ];

  static Future<List<ClassModel>> getTeacherClasses(String teacherId) async {
    final response = await supabase
        .from('classes')
        .select()
        .eq('teacher_id', teacherId)
        .order('created_at', ascending: false);
    
    return response.map<ClassModel>((json) => ClassModel.fromJson(json)).toList();
  }

  static Future<List<ClassModel>> getStudentClasses(String studentId) async {
    final response = await supabase
        .from('enrollments')
        .select('class_id')
        .eq('student_id', studentId);
    
    final classIds = response.map<String>((json) => json['class_id'].toString()).toList();
    
    if (classIds.isEmpty) return [];
    
    final classesResponse = await supabase
        .from('classes')
        .select()
        .filter('id', 'in', classIds)
        .order('created_at', ascending: false);
    
    return classesResponse.map<ClassModel>((json) => ClassModel.fromJson(json)).toList();
  }

  static Future<ClassModel> createClass({
    required String name,
    required String subject,
    required String teacherId,
    String? description,
  }) async {
    // Generate a random color for the class
    final randomColor = _classColors[Random().nextInt(_classColors.length)];
    // Convert to a positive int that will fit in PostgreSQL integer
    final colorValue = randomColor.value & 0x00FFFFFF; // Remove alpha channel
    
    final response = await supabase.from('classes').insert({
      'name': name,
      'subject': subject,
      'teacher_id': teacherId,
      'description': description,
      'color': colorValue,
      // Let the database handle created_at with its default value
    }).select();
    
    return ClassModel.fromJson(response.first);
  }

  static Future<String> generateClassCode(String classId) async {
    // Generate a random 6-character code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    final code = String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
    
    // Store the code in the database
    await supabase.from('class_codes').insert({
      'class_id': classId,
      'code': code,
      'created_at': DateTime.now().toIso8601String(),
    });
    
    return code;
  }

  static Future<ClassModel?> joinClassWithCode(String code, String studentId) async {
    // Find the class with this code
    final codeResponse = await supabase
        .from('class_codes')
        .select('class_id')
        .eq('code', code)
        .single();
    
    if (codeResponse == null) return null;
    
    final classId = codeResponse['class_id'];
    
    // Check if student is already enrolled
    final existingEnrollment = await supabase
        .from('enrollments')
        .select()
        .eq('class_id', classId)
        .eq('student_id', studentId);
    
    if (existingEnrollment.isNotEmpty) {
      // Already enrolled
      final classResponse = await supabase
          .from('classes')
          .select()
          .eq('id', classId)
          .single();
      
      return ClassModel.fromJson(classResponse);
    }
    
    // Enroll the student
    await supabase.from('enrollments').insert({
      'class_id': classId,
      'student_id': studentId,
      'joined_at': DateTime.now().toIso8601String(),
    });
    
    // Return the class details
    final classResponse = await supabase
        .from('classes')
        .select()
        .eq('id', classId)
        .single();
    
    return ClassModel.fromJson(classResponse);
  }

  static Future<void> archiveClass(String classId) async {
    await supabase
        .from('classes')
        .update({'archived': true})
        .eq('id', classId);
  }

  static Future<int> getStudentCount(String classId) async {
    final response = await supabase
        .from('enrollments')
        .select('count')
        .eq('class_id', classId);
    
    return response[0]['count'];
  }
} 