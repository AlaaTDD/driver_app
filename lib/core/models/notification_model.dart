import 'package:equatable/equatable.dart';

class NotificationModel extends Equatable {
  final String id;
  final String userId;
  final String title;
  final String message;
  final String type;
  final String? referenceId;
  final bool isRead;
  final DateTime createdAt;
  final String? titleAr;
  final String? bodyAr;

  const NotificationModel({
    required this.id,
    required this.userId,
    required this.title,
    required this.message,
    this.type = 'general',
    this.referenceId,
    this.isRead = false,
    required this.createdAt,
    this.titleAr,
    this.bodyAr,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      type: json['type'] as String? ?? 'general',
      referenceId: json['reference_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      titleAr: json['title_ar'] as String?,
      bodyAr: json['body_ar'] as String?,
    );
  }

  String localizedTitle(String language) {
    if (language == 'ar' && titleAr != null && titleAr!.isNotEmpty) {
      return titleAr!;
    }
    return title;
  }

  String localizedBody(String language) {
    if (language == 'ar' && bodyAr != null && bodyAr!.isNotEmpty) {
      return bodyAr!;
    }
    return message;
  }

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      userId: userId,
      title: title,
      message: message,
      type: type,
      referenceId: referenceId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt,
      titleAr: titleAr,
      bodyAr: bodyAr,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        title,
        message,
        type,
        referenceId,
        isRead,
        createdAt,
        titleAr,
        bodyAr,
      ];
}
