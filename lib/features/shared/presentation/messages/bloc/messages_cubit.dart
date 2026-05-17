import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../services/presence_service.dart';
import '../../../../../services/supabase_service.dart';
import '../../../data/repositories/messages_repository.dart';
import '../../../../../core/models/message_model.dart';
import 'messages_state.dart';

class MessagesCubit extends Cubit<MessagesState> {
  final MessagesRepository _repo;
  final PresenceService _presenceService;

  // Conversations subs
  StreamSubscription? _convRealtimeSub;
  // Chat subs
  StreamSubscription? _chatSub;
  // Presence
  StreamSubscription? _presenceSub;
  StreamSubscription? _globalPresenceSub;
  Timer? _onlineTimer;
  Timer? _typingThrottleTimer;

  MessagesCubit({MessagesRepository? repo, PresenceService? presenceService})
      : _repo = repo ?? MessagesRepository(),
        _presenceService = presenceService ?? PresenceService(),
        super(MessagesInitial());

  // ─── Conversations ───────────────────────────────────────────────

  Future<void> loadConversations() async {
    if (isClosed) return;
    emit(ConversationsLoading());
    try {
      final data = await _repo.loadConversations();
      if (isClosed) return;
      if (data.isEmpty) {
        emit(ConversationsLoaded([]));
      } else {
        emit(ConversationsLoaded(data));
      }
      if (isClosed) return;
      if (isClosed) return;
      _subscribeToConversationsRealtime();
    } catch (e) {
      if (isClosed) return;
      emit(MessagesError('failedLoadConversations'));
    }
  }

  void _subscribeToConversationsRealtime() {
    _convRealtimeSub?.cancel();
    _convRealtimeSub = _repo.watchConversations().listen((_) {
      if (isClosed) return;
      // Reload silently
      _repo.loadConversations().then((data) {
        if (!isClosed) emit(ConversationsLoaded(data));
      });
    });
  }

  // ─── Chat ────────────────────────────────────────────────────────

  Future<void> initDirectChat(String otherUserId,
      {String? otherUserName, String? tripId}) async {
    // Validate UUID format
    if (!_isValidUuid(otherUserId)) {
      emit(MessagesError('invalidUserId'));
      return;
    }
    if (isClosed) return;
    emit(MessagesChatLoaded(
      messages: const [],
      otherName: otherUserName ?? '',
      otherUserId: otherUserId,
      tripId: tripId,
      canSend: false,
    ));
    try {
      final canSend = await _repo.hasActiveTripWith(otherUserId);
      if (isClosed) return;
      final info = await _repo.fetchUserInfo(otherUserId);
      if (isClosed) return;
      final name = info?['name'] as String? ?? otherUserName ?? '';
      final avatar = info?['avatar_url'] as String?;
      final messages = await _repo.loadDirectMessages(otherUserId);
      if (isClosed) return;
      emit(MessagesChatLoaded(
        messages: messages,
        otherName: name,
        otherUserId: otherUserId,
        tripId: tripId,
        otherAvatarUrl: avatar,
        canSend: canSend,
        hasMore: messages.length >= 50,
      ));
      if (isClosed) return;
      _subscribeToDirectMessages(otherUserId);
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId != null) {
        final ids = [currentUserId, otherUserId]..sort();
        startPresence('presence-${ids.join('-')}');
      }
      // Subscribe to global presence for online/offline status
      _globalPresenceSub?.cancel();
      _globalPresenceSub =
          _repo.subscribeToUserGlobalPresence(otherUserId).listen((isOnline) {
        if (!isClosed && state is MessagesChatLoaded) {
          final current = state as MessagesChatLoaded;
          emit(MessagesChatLoaded(
            messages: current.messages,
            otherName: current.otherName,
            otherAvatarUrl: current.otherAvatarUrl,
            otherUserId: current.otherUserId,
            tripId: current.tripId,
            isOtherOnline: isOnline,
            isOtherTyping: current.isOtherTyping,
            canSend: current.canSend,
            hasMore: current.hasMore,
          ));
        }
      });
    } catch (e) {
      if (isClosed) return;
      emit(MessagesError('failedLoadMessages'));
    }
  }

  Future<void> initTripChat(String tripId) async {
    // Validate UUID format
    if (!_isValidUuid(tripId)) {
      emit(MessagesError('invalidTripId'));
      return;
    }
    if (isClosed) return;
    emit(MessagesChatLoaded(messages: []));
    try {
      final tripData = await _repo.fetchTripParticipants(tripId);
      if (isClosed) return;
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
      Map<String, dynamic>? info;
      if (otherId != null) {
        info = await _repo.fetchUserInfo(otherId);
        if (isClosed) return;
        otherName = info?['name'] as String? ?? '';
        otherAvatar = info?['avatar_url'] as String?;
      }
      final messages = await _repo.loadTripMessages(tripId);
      if (isClosed) return;
      emit(MessagesChatLoaded(
        messages: messages,
        otherName: otherName,
        otherUserId: otherId,
        tripId: tripId,
        otherAvatarUrl: otherAvatar,
        canSend: active, // Use the actual active state
        hasMore: messages.length >= 50,
      ));
      if (isClosed) return;
      _subscribeToTripMessages(tripId);
      final currentUserId = SupabaseService.currentUser?.id;
      if (currentUserId != null && otherId != null) {
        final ids = [currentUserId, otherId]..sort();
        startPresence('presence-${ids.join('-')}');

        // Subscribe to global presence for online/offline status
        _globalPresenceSub?.cancel();
        _globalPresenceSub =
            _repo.subscribeToUserGlobalPresence(otherId).listen((isOnline) {
          if (!isClosed && state is MessagesChatLoaded) {
            final current = state as MessagesChatLoaded;
            emit(MessagesChatLoaded(
              messages: current.messages,
              otherName: current.otherName,
              otherAvatarUrl: current.otherAvatarUrl,
              otherUserId: current.otherUserId,
              tripId: current.tripId,
              isOtherOnline: isOnline,
              isOtherTyping: current.isOtherTyping,
              canSend: current.canSend,
              hasMore: current.hasMore,
            ));
          }
        });
      }
    } catch (e) {
      if (isClosed) return;
      emit(MessagesError('failedLoadMessages'));
    }
  }

  Future<void> deleteMessage(String messageId, {required bool isSender}) async {
    try {
      await _repo.deleteMessage(messageId, isSender: isSender);
      if (isClosed) return;
      // Reload messages to refresh the list
      if (state is MessagesChatLoaded) {
        final current = state as MessagesChatLoaded;
        final messages =
            current.messages.where((m) => m.id != messageId).toList();
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

  Future<void> sendMessage(
    String text,
    String otherUserId, {
    String? tripId,
    required String Function(String name) newMessageFrom,
  }) async {
    if (state is! MessagesChatLoaded) return;
    final current = state as MessagesChatLoaded;
    if (current.canSend == false) {
      return;
    }
    final userId = SupabaseService.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      emit(MessagesError('userNotAuthenticated'));
      return;
    }
    if (otherUserId.isEmpty) {
      emit(MessagesError('invalidReceiverId'));
      return;
    }
    // Normalize empty tripId to null
    final normalizedTripId = (tripId == null || tripId.isEmpty) ? null : tripId;
    final optimistic = MessageModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: userId,
      receiverId: otherUserId,
      content: text,
      createdAt: DateTime.now(),
      isRead: false,
    );
    final updatedMessages = [optimistic, ...current.messages];
    emit(MessagesChatLoaded(
      messages: updatedMessages,
      otherName: current.otherName,
      otherUserId: current.otherUserId,
      tripId: current.tripId,
      otherAvatarUrl: current.otherAvatarUrl,
      isOtherOnline: current.isOtherOnline,
      isOtherTyping: current.isOtherTyping,
      canSend: current.canSend,
      hasMore: current.hasMore,
    ));
    try {
      if (normalizedTripId != null) {
        await _repo.sendTripMessageWithNotification(
          tripId: normalizedTripId,
          text: text,
          senderName: await _repo.fetchCurrentUserName() ?? 'User',
          newMessageFrom: newMessageFrom,
        );
      } else {
        await _repo.sendDirectMessage(
          receiverId: otherUserId,
          text: text,
          senderName: await _repo.fetchCurrentUserName() ?? 'User',
          newMessageFrom: newMessageFrom,
        );
      }
      // Stream will pick up the real message and replace the optimistic one.
    } catch (e) {
      if (isClosed) return;
      debugPrint('MessagesCubit: sendMessage failed: $e');
      emit(MessagesError('failedSendMessage'));
    }
  }

  Future<void> loadMoreMessages() async {
    if (state is! MessagesChatLoaded) return;
    final current = state as MessagesChatLoaded;
    final currentCount = current.messages.length;
    try {
      final messages = (current.hasMore && current.otherUserId != null)
          ? current.tripId != null
              ? await _repo.loadTripMessages(current.tripId!,
                  offset: currentCount)
              : await _repo.loadDirectMessages(current.otherUserId!,
                  offset: currentCount)
          : <MessageModel>[];
      if (isClosed) return;
      if (messages.isNotEmpty) {
        emit(MessagesChatLoaded(
          messages: [...current.messages, ...messages],
          otherName: current.otherName,
          otherUserId: current.otherUserId,
          otherAvatarUrl: current.otherAvatarUrl,
          tripId: current.tripId,
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
        final updated = List<MessageModel>.from(current.messages);
        bool hasUnread = false;
        final currentUserId = SupabaseService.currentUser?.id;
        for (final msg in msgs) {
          if (msg.senderId != currentUserId && !msg.isRead) {
            hasUnread = true;
          }
          final idx = updated.indexWhere((m) => m.id == msg.id);
          if (idx != -1) {
            updated[idx] = msg;
          } else {
            final optIdx = updated.indexWhere((m) =>
                m.senderId == msg.senderId &&
                m.content == msg.content &&
                m.id.length <
                    20); // Optimistic IDs are milliseconds (~13 chars)
            if (optIdx != -1) {
              updated[optIdx] = msg;
            } else {
              updated.add(msg);
            }
          }
        }

        if (hasUnread) {
          _repo.markAsRead(otherUserId);
        }
        updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        emit(MessagesChatLoaded(
          messages: updated,
          otherName: current.otherName,
          otherAvatarUrl: current.otherAvatarUrl,
          otherUserId: current.otherUserId,
          tripId: current.tripId,
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
        final updated = List<MessageModel>.from(current.messages);
        bool hasUnread = false;
        final currentUserId = SupabaseService.currentUser?.id;
        for (final msg in msgs) {
          if (msg.senderId != currentUserId && !msg.isRead) {
            hasUnread = true;
          }
          final idx = updated.indexWhere((m) => m.id == msg.id);
          if (idx != -1) {
            updated[idx] = msg;
          } else {
            final optIdx = updated.indexWhere((m) =>
                m.senderId == msg.senderId &&
                m.content == msg.content &&
                m.id.length < 20);
            if (optIdx != -1) {
              updated[optIdx] = msg;
            } else {
              updated.add(msg);
            }
          }
        }
        if (hasUnread && current.otherUserId != null) {
          _repo.markAsRead(current.otherUserId!, tripId: tripId);
        }
        updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        emit(MessagesChatLoaded(
          messages: updated,
          otherName: current.otherName,
          otherAvatarUrl: current.otherAvatarUrl,
          otherUserId: current.otherUserId,
          tripId: current.tripId,
          isOtherOnline: current.isOtherOnline,
          isOtherTyping: current.isOtherTyping,
          canSend: current.canSend,
          hasMore: current.hasMore,
        ));
      }
    });
  }

  // ─── Presence ─────────────────────────────────────────────────────

  void startPresence(String channelKey, {bool isTyping = false}) async {
    await _presenceService.startTracking(channelKey, isTyping: isTyping);
    _presenceService.onSync((onlineMap, typingMap) {
      if (state is MessagesChatLoaded) {
        final current = state as MessagesChatLoaded;
        // Don't override isOnline here anymore, let global presence handle it!
        final isOtherTyping = typingMap[current.otherUserId] ?? false;
        if (current.isOtherTyping != isOtherTyping) {
          emit(MessagesChatLoaded(
            messages: current.messages,
            otherName: current.otherName,
            otherAvatarUrl: current.otherAvatarUrl,
            otherUserId: current.otherUserId,
            tripId: current.tripId,
            isOtherOnline: current.isOtherOnline, // Kept from global presence
            isOtherTyping: isOtherTyping,
            canSend: current.canSend,
            hasMore: current.hasMore,
          ));
        }
      }
    });
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
    await _chatSub?.cancel();
    await _presenceSub?.cancel();
    await _globalPresenceSub?.cancel();
    _onlineTimer?.cancel();
    _typingThrottleTimer?.cancel();
    await _presenceService.dispose();
    return super.close();
  }
}
