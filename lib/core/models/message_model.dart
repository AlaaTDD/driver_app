
import 'package:equatable/equatable.dart';





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
      
      content: (json['content'] ?? json['message'] ?? '') as String,
      isRead: json['is_read'] as bool? ?? false,
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
    };
  }

  
  bool isSentBy(String userId) => senderId == userId;

  @override
  List<Object?> get props => [
        id, senderId, receiverId, tripId, content, isRead, createdAt,
      ];
}
