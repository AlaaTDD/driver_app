// lib/core/models/support_message_model.dart
import 'package:equatable/equatable.dart';

/// Type-safe model for the `support_messages` table.
///
/// Schema columns: id, user_id, message, created_at, sender_role.
/// sender_role distinguishes user messages from support/AI replies.
class SupportMessageModel extends Equatable {
  final String id;
  final String userId;
  final String message;
  final DateTime createdAt;

  /// DB column `sender_role` — 'user' or 'support'.
  final String senderRole;

  /// Convenience getter derived from sender_role.
  bool get isFromUser => senderRole == 'user';

  const SupportMessageModel({
    required this.id,
    required this.userId,
    required this.message,
    required this.createdAt,
    this.senderRole = 'user',
  });

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    final rawRole = json['sender_role'] as String?;
    return SupportMessageModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      message: json['message'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      senderRole: rawRole ?? 'user',
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'message': message,
      'sender_role': senderRole,
    };
  }

  @override
  List<Object?> get props => [id, userId, message, createdAt, senderRole];
}
