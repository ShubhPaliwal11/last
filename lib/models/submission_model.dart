class SubmissionModel {
  final String id;
  final String assignmentId;
  final String studentId;
  final DateTime submittedAt;
  final String? fileUrl;
  final int? points;
  final String? feedback;
  final DateTime? gradedAt;
  final String status; // Value must be one of: 'pending', 'reviewed'

  SubmissionModel({
    required this.id,
    required this.assignmentId,
    required this.studentId,
    required this.submittedAt,
    this.fileUrl,
    this.points,
    this.feedback,
    this.gradedAt,
    required this.status,
  });

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    return SubmissionModel(
      id: json['id'],
      assignmentId: json['assignment_id'],
      studentId: json['student_id'],
      submittedAt: DateTime.parse(json['submitted_at']),
      fileUrl: json['file_url'],
      points: json['points'],
      feedback: json['feedback'],
      gradedAt: json['graded_at'] != null ? DateTime.parse(json['graded_at']) : null,
      status: json['status'] ?? 'pending', // Default to 'pending' if not specified
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assignment_id': assignmentId,
      'student_id': studentId,
      'submitted_at': submittedAt.toIso8601String(),
      'file_url': fileUrl,
      'points': points,
      'feedback': feedback,
      'graded_at': gradedAt?.toIso8601String(),
      'status': status,
    };
  }
} 