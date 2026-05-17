import 'package:equatable/equatable.dart';
import '../../../../../core/models/message_model.dart';

abstract class MessagesState extends Equatable {
  const MessagesState();
  @override
  List<Object?> get props => [];
}

class MessagesInitial extends MessagesState {}

class ConversationsLoading extends MessagesState {}

class ConversationsLoaded extends MessagesState {
  final List<Map<String, dynamic>> conversations;
  final Map<String, bool> onlineMap;
  const ConversationsLoaded(this.conversations, {this.onlineMap = const {}});
  @override
  List<Object?> get props => [conversations, onlineMap];
}

class MessagesChatLoaded extends MessagesState {
  final List<MessageModel> messages;
  final String otherName;
  final String? otherAvatarUrl;
  final String? otherUserId;
  final String? tripId;
  final bool isOtherOnline;
  final bool isOtherTyping;
  final bool canSend;
  final bool hasMore;
  const MessagesChatLoaded({
    required this.messages,
    this.otherName = '',
    this.otherAvatarUrl,
    this.otherUserId,
    this.tripId,
    this.isOtherOnline = false,
    this.isOtherTyping = false,
    this.canSend = true,
    this.hasMore = true,
  });
  @override
  List<Object?> get props => [
        messages,
        otherName,
        otherUserId,
        tripId,
        isOtherOnline,
        isOtherTyping,
        canSend,
        hasMore
      ];
}

class MessagesError extends MessagesState {
  final String message;
  const MessagesError(this.message);
  @override
  List<Object?> get props => [message];
}

class MessagesSending extends MessagesState {
  final List<MessageModel> currentMessages;
  const MessagesSending(this.currentMessages);
  @override
  List<Object?> get props => [currentMessages];
}
