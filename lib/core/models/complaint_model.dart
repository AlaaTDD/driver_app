import 'package:equatable/equatable.dart';

class ComplaintModel extends Equatable {
  final String id;
  final String? userId;
  final String? tripId;
  final String title;
  final String description;
  final String status;
  final String? category;
  final String? priority;
  final String? adminReply;
  final String? adminNotes;
  final DateTime? repliedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ComplaintModel({
    required this.id,
    this.userId,
    this.tripId,
    this.title = '',
    this.description = '',
    this.status = 'pending',
    this.category,
    this.priority,
    this.adminReply,
    this.adminNotes,
    this.repliedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory ComplaintModel.fromJson(Map<String, dynamic> json) {
    return ComplaintModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      tripId: json['trip_id'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      category: json['category'] as String?,
      priority: json['priority'] as String?,
      adminReply: json['admin_reply']?.toString(),
      adminNotes: json['admin_notes']?.toString(),
      repliedAt: _date(json['replied_at']),
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'trip_id': tripId,
        'title': title,
        'description': description,
        'status': status,
        'category': category,
        'priority': priority,
        'admin_reply': adminReply,
        'admin_notes': adminNotes,
        'replied_at': repliedAt?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        tripId,
        title,
        description,
        status,
        category,
        priority,
        adminReply,
        adminNotes,
        repliedAt,
        createdAt,
        updatedAt,
      ];
}
