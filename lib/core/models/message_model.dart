// lib/core/models/message_model.dart
import 'package:equatable/equatable.dart';

/// Type-safe model for the `messages` table (trip chat).
///
/// IMPORTANT: The schema column for message text is `content` (NOT `message`).
/// The code was previously inserting to `message` which is incorrect.
class MessageModel extends Equatable {
  final String id;
  final String senderId;
  final String receiverId;
  final String? tripId;
  final String content;
  final bool isRead;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.tripId,
    required this.content,
    this.isRead = false,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      senderId: json['sender_id'] as String,
      receiverId: json['receiver_id'] as String,
      tripId: json['trip_id'] as String?,
      // Schema column is 'content', but handle legacy 'message' key as fallback
      content: (json['content'] ?? json['message'] ?? '') as String,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Convert to JSON for database INSERT.
  /// Uses the correct schema column name `content`.
  Map<String, dynamic> toInsertJson() {
    return {
      'sender_id': senderId,
      'receiver_id': receiverId,
      if (tripId != null) 'trip_id': tripId,
      'content': content,
    };
  }

  /// Whether this message was sent by the given userId.
  bool isSentBy(String userId) => senderId == userId;

  @override
  List<Object?> get props => [
        id, senderId, receiverId, tripId, content, isRead, createdAt,
      ];
}
