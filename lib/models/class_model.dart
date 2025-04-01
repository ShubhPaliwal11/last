import 'package:flutter/material.dart';

class ClassModel {
  final String id;
  final String name;
  final String subject;
  final String teacherId;
  final String? description;
  final Color color;
  final String? bannerUrl;
  final DateTime createdAt;
  final List<String>? studentIds;
  
  ClassModel({
    required this.id,
    required this.name,
    required this.subject,
    required this.teacherId,
    this.description,
    required this.color,
    this.bannerUrl,
    required this.createdAt,
    this.studentIds,
  });
  
  factory ClassModel.fromJson(Map<String, dynamic> json) {
    return ClassModel(
      id: json['id'],
      name: json['name'],
      subject: json['subject'],
      teacherId: json['teacher_id'],
      description: json['description'],
      color: Color(json['color'] ?? 0xFF2196F3),
      bannerUrl: json['banner_url'],
      createdAt: DateTime.parse(json['created_at']),
      studentIds: json['student_ids'] != null 
          ? List<String>.from(json['student_ids']) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subject': subject,
      'teacher_id': teacherId,
      'description': description,
      'color': color.value,
      'banner_url': bannerUrl,
      'created_at': createdAt.toIso8601String(),
      'student_ids': studentIds,
    };
  }
} 