
import 'package:equatable/equatable.dart';





class MessageModel extends Equatable {
  final String id;
  final String senderId;
  final String receiverId;
  final String? tripId;
  final String content;
  final String type; // 'text', 'image', 'location', 'voice'
  final String? attachmentUrl;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.tripId,
    required this.content,
    this.type = 'text',
    this.attachmentUrl,
    this.isRead = false,
    this.readAt,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] as String?) ?? '';
    return MessageModel(
      id: (json['id'] as String?) ?? '',
      senderId: (json['sender_id'] as String?) ?? '',
      receiverId: (json['receiver_id'] as String?) ?? '',
      tripId: json['trip_id'] as String?,
      content: content.isNotEmpty ? content : (json['message'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'text',
      attachmentUrl: json['attachment_url'] as String?,
      isRead: (json['is_read'] as bool?) ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'sender_id': senderId,
      'receiver_id': receiverId,
      if (tripId != null) 'trip_id': tripId,
      'content': content,
      'type': type,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (readAt != null) 'read_at': readAt!.toUtc().toIso8601String(),
    };
  }

  bool isSentBy(String userId) => senderId == userId;

  @override
  List<Object?> get props => [
        id,
        senderId,
        receiverId,
        tripId,
        content,
        type,
        attachmentUrl,
        isRead,
        readAt,
        createdAt,
      ];
}
