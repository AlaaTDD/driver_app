import 'package:equatable/equatable.dart';

class ConversationModel extends Equatable {
  final String otherUserId;
  final String otherUserName;
  final String? otherUserAvatar;
  final String otherUserRole;
  final String lastMessage;
  final String? lastMessageAt;
  final bool isMeSender;
  final bool isRead;
  final int unreadCount;

  const ConversationModel({
    required this.otherUserId,
    this.otherUserName = '',
    this.otherUserAvatar,
    this.otherUserRole = 'user',
    this.lastMessage = '',
    this.lastMessageAt,
    this.isMeSender = false,
    this.isRead = true,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      otherUserId: json['other_user_id'] as String? ?? '',
      otherUserName: json['other_user_name'] as String? ?? '',
      otherUserAvatar: json['other_user_avatar'] as String?,
      otherUserRole: json['other_user_role'] as String? ?? 'user',
      lastMessage: json['last_message'] as String? ?? '',
      lastMessageAt: json['last_message_at']?.toString(),
      isMeSender: json['is_me_sender'] as bool? ?? false,
      isRead: json['is_read'] as bool? ?? true,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'other_user_id': otherUserId,
        'other_user_name': otherUserName,
        'other_user_avatar': otherUserAvatar,
        'other_user_role': otherUserRole,
        'last_message': lastMessage,
        'last_message_at': lastMessageAt,
        'is_me_sender': isMeSender,
        'is_read': isRead,
        'unread_count': unreadCount,
      };

  @override
  List<Object?> get props => [
        otherUserId,
        otherUserName,
        otherUserAvatar,
        otherUserRole,
        lastMessage,
        lastMessageAt,
        isMeSender,
        isRead,
        unreadCount,
      ];
}
