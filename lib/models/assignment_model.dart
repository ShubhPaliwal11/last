class AssignmentModel {
  final String id;
  final String title;
  final String description;
  final String classId;
  final String teacherId;
  final DateTime createdAt;
  final DateTime dueDate;
  final int? maxPoints;
  final String? fileUrl;
  
  AssignmentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.classId,
    required this.teacherId,
    required this.createdAt,
    required this.dueDate,
    this.maxPoints,
    this.fileUrl,
  });
  
  factory AssignmentModel.fromJson(Map<String, dynamic> json) {
    return AssignmentModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      classId: json['class_id'],
      teacherId: json['teacher_id'],
      createdAt: DateTime.parse(json['created_at']),
      dueDate: DateTime.parse(json['due_date']),
      maxPoints: json['max_points'],
      fileUrl: json['file_url'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'class_id': classId,
      'teacher_id': teacherId,
      'created_at': createdAt.toIso8601String(),
      'due_date': dueDate.toIso8601String(),
      'max_points': maxPoints,
      'file_url': fileUrl,
    };
  }
} 