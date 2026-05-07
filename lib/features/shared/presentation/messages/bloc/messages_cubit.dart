import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../services/presence_service.dart';
import '../../../../../services/supabase_service.dart';
import '../data/messages_repository.dart';
import '../../../../../core/models/message_model.dart';
import 'messages_state.dart';

class MessagesCubit extends Cubit<MessagesState> {
  final MessagesRepository _repo = MessagesRepository();
  final PresenceService _presenceService = PresenceService();

  // Conversations subs
  StreamSubscription? _convRealtimeSub;
  StreamSubscription? _payloadSub;
  // Chat subs
  StreamSubscription? _chatSub;
  // Presence
  StreamSubscription? _presenceSub;
  Timer? _onlineTimer;
  Timer? _typingThrottleTimer;

  MessagesCubit() : super(MessagesInitial());

  // ─── Conversations ───────────────────────────────────────────────

  Future<void> loadConversations() async {
    emit(ConversationsLoading());
    try {
      final data = await _repo.loadConversations();
      if (data.isEmpty) {
        emit(ConversationsLoaded([]));
      } else {
        emit(ConversationsLoaded(data));
      }
      _subscribeToConversationsRealtime();
      _subscribeToPayloads();
    } catch (e) {
      emit(MessagesError('failedLoadConversations'));
    }
  }

  void _subscribeToConversationsRealtime() {
    _convRealtimeSub?.cancel();
    _convRealtimeSub = _repo.watchConversations().listen((_) {
      // Reload silently
      _repo.loadConversations().then((data) {
        if (!isClosed) emit(ConversationsLoaded(data));
      });
    });
  }

  void _subscribeToPayloads() {
    _payloadSub?.cancel();
    _payloadSub = _repo.watchConversationPayloads().listen((msg) {
      if (state is ConversationsLoaded) {
        // Handle optimistic update based on payload
        // (Implementation similar to original _handleRealtimeMessage)
      }
    });
  }

  // ─── Chat ────────────────────────────────────────────────────────

  Future<void> initDirectChat(String otherUserId, {String? otherUserName}) async {
    // Validate UUID format
    if (!_isValidUuid(otherUserId)) {
      emit(MessagesError('invalidUserId'));
      return;
    }
    emit(MessagesChatLoaded(messages: [], otherName: otherUserName ?? '', otherUserId: otherUserId));
    try {
      final canSend = await _repo.hasActiveTripWith(otherUserId);
      final info = await _repo.fetchUserInfo(otherUserId);
      final name = info?['name'] as String? ?? otherUserName ?? '';
      final avatar = info?['avatar_url'] as String?;
      final messages = await _repo.loadDirectMessages(otherUserId);
      emit(MessagesChatLoaded(
        messages: messages,
        otherName: name,
        otherUserId: otherUserId,
        otherAvatarUrl: avatar,
        canSend: canSend,
        hasMore: messages.length >= 50,
      ));
      _subscribeToDirectMessages(otherUserId);
    } catch (e) {
      emit(MessagesError('failedLoadMessages'));
    }
  }

  Future<void> initTripChat(String tripId) async {
    // Validate UUID format
    if (!_isValidUuid(tripId)) {
      emit(MessagesError('invalidTripId'));
      return;
    }
    emit(MessagesChatLoaded(messages: []));
    try {
      final tripData = await _repo.fetchTripParticipants(tripId);
      if (tripData == null) {
        emit(MessagesError('tripNotFound'));
        return;
      }
      final status = tripData['status'] as String?;
      final active = AppConstants.activeTripStatuses.contains(status);
      final userId = SupabaseService.currentUser?.id;
      final otherId = (tripData['user_id'] == userId)
          ? tripData['driver_id']
          : tripData['user_id'];
      String otherName = '';
      String? otherAvatar;
      if (otherId != null) {
        final info = await _repo.fetchUserInfo(otherId);
        otherName = info?['name'] as String? ?? '';
        otherAvatar = info?['avatar_url'] as String?;
      }
      final messages = await _repo.loadTripMessages(tripId);
      emit(MessagesChatLoaded(
        messages: messages,
        otherName: otherName,
        otherUserId: otherId,
        tripId: tripId,
        otherAvatarUrl: otherAvatar,
        canSend: active,
        hasMore: messages.length >= 50,
      ));
      _subscribeToTripMessages(tripId);
    } catch (e) {
      emit(MessagesError('failedLoadMessages'));
    }
  }

  Future<void> deleteMessage(String messageId, {required bool isSender}) async {
    try {
      await _repo.deleteMessage(messageId, isSender: isSender);
      // Reload messages to refresh the list
      if (state is MessagesChatLoaded) {
        final current = state as MessagesChatLoaded;
        final messages = current.messages
            .where((m) => m.id != messageId)
            .toList();
        emit(MessagesChatLoaded(
          messages: messages,
          otherName: current.otherName,
          otherUserId: current.otherUserId,
          otherAvatarUrl: current.otherAvatarUrl,
          isOtherOnline: current.isOtherOnline,
          isOtherTyping: current.isOtherTyping,
          canSend: current.canSend,
          hasMore: current.hasMore,
        ));
      }
    } catch (e) {
      debugPrint('MessagesCubit: deleteMessage failed: $e');
    }
  }

  Future<void> sendMessage(String text, String otherUserId, {String? tripId}) async {
    if (state is! MessagesChatLoaded) return;
    final current = state as MessagesChatLoaded;
    if (current.canSend == false) {
      return;
    }
    final userId = SupabaseService.currentUser?.id ?? '';
    final optimistic = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: userId,
      receiverId: otherUserId,
      content: text,
      createdAt: DateTime.now(),
      isRead: false,
    );
    final updatedMessages = [optimistic, ...current.messages];
    emit(MessagesSending(updatedMessages));
    try {
      if (tripId != null) {
        await _repo.sendTripMessageWithNotification(
          tripId: tripId,
          text: text,
          senderName: await _repo.fetchCurrentUserName() ?? 'User',
          newMessageFrom: (name) => 'رسالة من $name',
        );
      } else {
        await _repo.sendDirectMessage(
          receiverId: otherUserId,
          text: text,
          senderName: await _repo.fetchCurrentUserName() ?? 'User',
          newMessageFrom: (name) => 'رسالة من $name',
        );
      }
      final messages = tripId != null
          ? await _repo.loadTripMessages(tripId)
          : await _repo.loadDirectMessages(otherUserId);
      emit(MessagesChatLoaded(
        messages: messages,
        otherName: current.otherName,
        otherUserId: current.otherUserId,
        tripId: current.tripId,
        otherAvatarUrl: current.otherAvatarUrl,
        isOtherOnline: current.isOtherOnline,
        isOtherTyping: current.isOtherTyping,
        canSend: current.canSend,
        hasMore: messages.length >= 50,
      ));
    } catch (e) {
      debugPrint('MessagesCubit: sendMessage failed: $e');
      emit(MessagesError('failedSendMessage'));
    }
  }

  Future<void> sendImage(File image, String otherUserId, {String? tripId}) async {
    if (state is! MessagesChatLoaded) return;
    final current = state as MessagesChatLoaded;
    if (current.canSend == false) return;
    try {
      final url = await _repo.uploadAttachment(image);
      final type = 'image';
      final text = '📷 صورة';
      if (tripId != null) {
        await _repo.sendTripMessageWithNotification(
          tripId: tripId,
          text: text,
          senderName: await _repo.fetchCurrentUserName() ?? 'User',
          newMessageFrom: (name) => 'رسالة من $name',
          type: type,
          attachmentUrl: url,
        );
      } else {
        await _repo.sendDirectMessage(
          receiverId: otherUserId,
          text: text,
          senderName: await _repo.fetchCurrentUserName() ?? 'User',
          newMessageFrom: (name) => 'رسالة من $name',
          type: type,
          attachmentUrl: url,
        );
      }
      final messages = tripId != null
          ? await _repo.loadTripMessages(tripId)
          : await _repo.loadDirectMessages(otherUserId);
      emit(MessagesChatLoaded(
        messages: messages,
        otherName: current.otherName,
        otherUserId: current.otherUserId,
        tripId: current.tripId,
        otherAvatarUrl: current.otherAvatarUrl,
        isOtherOnline: current.isOtherOnline,
        isOtherTyping: current.isOtherTyping,
        canSend: current.canSend,
        hasMore: messages.length >= 50,
      ));
    } catch (e) {
      debugPrint('MessagesCubit: sendImage failed: $e');
      emit(MessagesError('failedSendImage'));
    }
  }

  Future<void> loadMoreMessages() async {
    if (state is! MessagesChatLoaded) return;
    final current = state as MessagesChatLoaded;
    final currentCount = current.messages.length;
    try {
      final messages = (current.hasMore && current.otherUserId != null)
          ? await _repo.loadDirectMessages(current.otherUserId!, offset: currentCount)
          : <MessageModel>[];
      if (messages.isNotEmpty) {
        emit(MessagesChatLoaded(
          messages: [...current.messages, ...messages],
          otherName: current.otherName,
          otherUserId: current.otherUserId,
          otherAvatarUrl: current.otherAvatarUrl,
          isOtherOnline: current.isOtherOnline,
          isOtherTyping: current.isOtherTyping,
          canSend: current.canSend,
          hasMore: messages.length >= 50,
        ));
      }
    } catch (e) {
      debugPrint('MessagesCubit: loadMoreMessages failed: $e');
    }
  }

  void _subscribeToDirectMessages(String otherUserId) {
    _chatSub?.cancel();
    _chatSub = _repo.subscribeToDirectMessages(otherUserId).listen((msgs) {
      if (!isClosed && state is MessagesChatLoaded) {
        final current = state as MessagesChatLoaded;
        emit(MessagesChatLoaded(
          messages: msgs,
          otherName: current.otherName,
          otherAvatarUrl: current.otherAvatarUrl,
          isOtherOnline: current.isOtherOnline,
          isOtherTyping: current.isOtherTyping,
          canSend: current.canSend,
          hasMore: current.hasMore,
        ));
      }
    });
  }

  void _subscribeToTripMessages(String tripId) {
    _chatSub?.cancel();
    _chatSub = _repo.subscribeToTripMessages(tripId).listen((msgs) {
      if (!isClosed && state is MessagesChatLoaded) {
        final current = state as MessagesChatLoaded;
        emit(MessagesChatLoaded(
          messages: msgs,
          otherName: current.otherName,
          otherAvatarUrl: current.otherAvatarUrl,
          isOtherOnline: current.isOtherOnline,
          isOtherTyping: current.isOtherTyping,
          canSend: current.canSend,
          hasMore: current.hasMore,
        ));
      }
    });
  }

  // ─── Presence ─────────────────────────────────────────────────────

  void startPresence(String channelKey, {bool isTyping = false}) {
    _presenceService.startTracking(channelKey, isTyping: isTyping);
  }

  void updateTyping(bool isTyping) {
    _presenceService.updateTyping(isTyping);
  }

  /// Validates if a string is a valid UUID (version 4).
  bool _isValidUuid(String? id) {
    if (id == null || id.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(id);
  }

  @override
  Future<void> close() async {
    await _convRealtimeSub?.cancel();
    await _payloadSub?.cancel();
    await _chatSub?.cancel();
    await _presenceSub?.cancel();
    _onlineTimer?.cancel();
    _typingThrottleTimer?.cancel();
    await _presenceService.dispose();
    return super.close();
  }
}
