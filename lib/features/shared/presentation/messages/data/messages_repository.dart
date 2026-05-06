
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/models/message_model.dart';
import '../../../../../services/supabase_service.dart';

/// Repository for direct user↔driver messaging (messages table)
/// and trip-scoped chat.
/// complaints table is handled separately by ComplaintsRepository.
class MessagesRepository {
  // ─── Conversations list ───────────────────────────────────────────────────

  /// Returns a list of "conversations" – one entry per unique counterpart.
  /// Each entry has: other_user_id, other_user_name, other_user_avatar,
  /// last_message, last_message_at, unread_count.
  Future<List<Map<String, dynamic>>> loadConversations() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    try {
      // Fetch all messages where I am sender OR receiver (excluding soft-deleted for me)
      final data = await SupabaseService.client
          .from('messages')
          .select('id, sender_id, receiver_id, content, created_at, is_read')
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .or('and(deleted_by_sender.eq.false,deleted_by_receiver.eq.false)')
          .order('created_at', ascending: false)
          .limit(50);

      if (data.isEmpty) return [];

      // Build unread counts per other user
      final Map<String, int> unreadCounts = {};
      for (final row in data) {
        final s = row['sender_id'] as String;
        final r = row['receiver_id'] as String;
        if (r == userId && !(row['is_read'] as bool? ?? false)) {
          final sender = s;
          unreadCounts[sender] = (unreadCounts[sender] ?? 0) + 1;
        }
      }

      // Build a map of counterpart_id → last message
      final Map<String, Map<String, dynamic>> convMap = {};
      for (final row in data) {
        final senderId = row['sender_id'] as String;
        final receiverId = row['receiver_id'] as String;
        final otherId = (senderId == userId) ? receiverId : senderId;

        if (convMap.containsKey(otherId)) continue; // already have last msg

        convMap[otherId] = {
          'other_user_id': otherId,
          'last_message': row['content'] as String? ?? '',
          'last_message_at': row['created_at'],
          'is_me_sender': senderId == userId,
          'is_read': row['is_read'] as bool? ?? true,
          'unread_count': unreadCounts[otherId] ?? 0,
        };
      }

      if (convMap.isEmpty) return [];

      // Fetch names for all counterparts in one query
      final otherIds = convMap.keys.toList();
      final users = await SupabaseService.client
          .from('users')
          .select('id, name, avatar_url, role')
          .inFilter('id', otherIds);

      final List<Map<String, dynamic>> result = [];
      for (final user in users) {
        final uid = user['id'] as String;
        final conv = convMap[uid];
        if (conv == null) continue;
        result.add({
          ...conv,
          'other_user_name': user['name'] as String? ?? '',
          'other_user_avatar': user['avatar_url'],
          'other_user_role': user['role'] as String? ?? 'user',
        });
      }

      // Sort by last_message_at descending
      result.sort((a, b) {
        final aTime = a['last_message_at'] as String? ?? '';
        final bTime = b['last_message_at'] as String? ?? '';
        return bTime.compareTo(aTime);
      });

      return result;
    } catch (e) {
      debugPrint('❌ MessagesRepository: loadConversations failed: $e');
      return [];
    }
  }

  // ─── Direct chat (no tripId) ──────────────────────────────────────────────

  /// Load all messages between the current user and [otherUserId].
  Future<List<MessageModel>> loadDirectMessages(String otherUserId) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final data = await SupabaseService.client
        .from('messages')
        .select('*')
        .or('and(sender_id.eq.$userId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$userId)')
        .isFilter('trip_id', null)
        .or('and(sender_id.eq.$userId,deleted_by_sender.eq.false),and(receiver_id.eq.$userId,deleted_by_receiver.eq.false)')
        .order('created_at', ascending: true);

    // Mark received messages as read (scoped to direct chat only)
    await markAsRead(otherUserId, tripId: null);

    return (data as List)
        .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Realtime stream of messages between current user and [otherUserId].
  Stream<List<MessageModel>> subscribeToDirectMessages(String otherUserId) {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return const Stream.empty();

    final controller = StreamController<List<MessageModel>>.broadcast();

    void handlePayload(PostgresChangePayload payload) {
      final newRow = payload.newRecord;
      final s = newRow['sender_id'] as String?;
      final r = newRow['receiver_id'] as String?;
      final tid = newRow['trip_id'];
      if (tid == null &&
          ((s == userId && r == otherUserId) || (s == otherUserId && r == userId))) {
        // Re-fetch scoped messages for simplicity and correctness
        loadDirectMessages(otherUserId).then((msgs) {
          if (!controller.isClosed) controller.add(msgs);
        });
      }
    }

    final channel = SupabaseService.client
        .channel('direct-messages-$userId-$otherUserId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: handlePayload,
        )
        .subscribe();

    controller.onCancel = () {
      SupabaseService.client.removeChannel(channel);
    };

    // Initial load
    loadDirectMessages(otherUserId).then((msgs) {
      if (!controller.isClosed) controller.add(msgs);
    });

    return controller.stream;
  }

  /// Send a direct message (no trip) and push notification + FCM.
  Future<void> sendDirectMessage({
    required String receiverId,
    required String text,
    required String senderName,
    required String Function(String name) newMessageFrom,
    String? defaultUserName,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    // Insert message
    await SupabaseService.client.from('messages').insert({
      'sender_id': userId,
      'receiver_id': receiverId,
      'content': text,
      'trip_id': null,
    });

    // Notification title: e.g. "رسالة من أحمد"
    final resolvedName = senderName.isNotEmpty ? senderName : (defaultUserName ?? 'User');
    final title = newMessageFrom(resolvedName);

    // DB notification (in-app)
    await _createNotification(
      receiverId: receiverId,
      title: title,
      message: text,
      type: 'new_message',
    );

    // FCM push (works while app is background / terminated)
    await _sendFcmPush(
      userId: receiverId,
      title: title,
      body: text,
      data: {
        'type': 'new_message',
        'senderId': userId,
        'senderName': resolvedName,
        'screen': 'messages',
      },
    );
  }

  // ─── Trip chat ────────────────────────────────────────────────────────────

  Future<List<MessageModel>> loadTripMessages(String tripId) async {
    final data = await SupabaseService.client
        .from('messages')
        .select('*')
        .eq('trip_id', tripId)
        .order('created_at', ascending: true);

    return (data as List)
        .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Stream<List<MessageModel>> subscribeToTripMessages(String tripId) {
    return SupabaseService.client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .order('created_at', ascending: true)
        .map((data) => data
            .map((e) => MessageModel.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  Future<void> sendTripMessageWithNotification({
    required String tripId,
    required String text,
    required String senderName,
    required String Function(String name) newMessageFrom,
    String? defaultDriverName,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    final receiverId = await _resolveReceiverId(tripId, userId);
    if (receiverId == null) return;

    // Insert message
    await SupabaseService.client.from('messages').insert({
      'trip_id': tripId,
      'sender_id': userId,
      'receiver_id': receiverId,
      'content': text,
    });

    final resolvedName = senderName.isNotEmpty ? senderName : (defaultDriverName ?? 'Driver');
    final title = newMessageFrom(resolvedName);

    // DB notification (in-app)
    await _createNotification(
      receiverId: receiverId,
      title: title,
      message: text,
      type: 'new_message',
      referenceId: tripId,
    );

    // FCM push (works while app is background / terminated)
    await _sendFcmPush(
      userId: receiverId,
      title: title,
      body: text,
      data: {
        'type': 'new_message',
        'tripId': tripId,
        'senderId': userId,
        'senderName': resolvedName,
        'screen': 'messages',
      },
    );
  }

  // ─── Mark as read ─────────────────────────────────────────────────────────

  Future<void> markAsRead(String senderId, {String? tripId}) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    try {
      var query = SupabaseService.client
          .from('messages')
          .update({'is_read': true, 'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('sender_id', senderId)
          .eq('receiver_id', userId)
          .eq('is_read', false);

      if (tripId != null) {
        query = query.eq('trip_id', tripId);
      } else {
        query = query.isFilter('trip_id', null);
      }

      await query;
    } catch (e) {
      debugPrint('⚠️ MessagesRepository: _markAsRead failed: $e');
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchTripParticipants(String tripId) async {
    return await SupabaseService.client
        .from('trips')
        .select('user_id, driver_id')
        .eq('id', tripId)
        .maybeSingle();
  }

  Future<String?> fetchUserName(String userId) async {
    final data = await SupabaseService.client
        .from('users')
        .select('name')
        .eq('id', userId)
        .maybeSingle();
    return data?['name'] as String?;
  }

  Future<String?> fetchCurrentUserName() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;
    return fetchUserName(userId);
  }

  Future<Map<String, dynamic>?> fetchUserInfo(String userId) async {
    return await SupabaseService.client
        .from('users')
        .select('id, name, avatar_url, role')
        .eq('id', userId)
        .maybeSingle();
  }

  Future<String?> _resolveReceiverId(String tripId, String senderId) async {
    final tripData = await fetchTripParticipants(tripId);
    if (tripData == null) return null;
    final tripUserId = tripData['user_id'] as String?;
    final tripDriverId = tripData['driver_id'] as String?;
    if (senderId == tripUserId) return tripDriverId;
    if (senderId == tripDriverId) return tripUserId;
    return null;
  }

  Stream<int> getUnreadMessagesCountStream(String userId) {
    final controller = StreamController<int>.broadcast();

    Future<void> fetchCount() async {
      try {
        final result = await SupabaseService.client
            .rpc('get_unread_message_count', params: {'p_user_id': userId});
        // RPC returns a list of rows; sum the counts
        int total = 0;
        if (result is List) {
          for (final row in result) {
            if (row is Map && row['unread_count'] != null) {
              total += (row['unread_count'] as num).toInt();
            }
          }
        }
        controller.add(total);
      } catch (e) {
        controller.add(0);
      }
    }

    fetchCount();

    final channel = SupabaseService.client
        .channel('unread-messages-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (_) => fetchCount(),
        )
        .subscribe();

    controller.onCancel = () {
      SupabaseService.client.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<void> _createNotification({
    required String receiverId,
    required String title,
    required String message,
    required String type,
    String? referenceId,
  }) async {
    try {
      await SupabaseService.client.from('notifications').insert({
        'user_id': receiverId,
        'title': title,
        'title_ar': title,
        'message': message,
        'body_ar': message,
        'type': type,
        'reference_id': referenceId,
      });
    } catch (e) {
      debugPrint('⚠️ MessagesRepository: createNotification failed: $e');
    }
  }

  Future<void> _sendFcmPush({
    required String userId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    try {
      await SupabaseService.client.functions.invoke('send-fcm', body: {
        'user_id': userId,
        'title': title,
        'body': body,
        'data': data,
      });
    } catch (e) {
      debugPrint('⚠️ MessagesRepository: send-fcm failed: $e');
    }
  }

  // ─── Presence heartbeat (chat context) ──────────────────────────────────

  /// Updates last_seen for current user without lat/lng.
  /// Call every 10s while user is in a chat screen.
  Future<void> ensureMyPresence({double? lat, double? lng}) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    try {
      final payload = <String, dynamic>{
        'user_id': userId,
        'last_seen': DateTime.now().toUtc().toIso8601String(),
      };
      if (lat != null) payload['lat'] = lat;
      if (lng != null) payload['lng'] = lng;
      await SupabaseService.client.from('user_presence').upsert(
        payload,
        onConflict: 'user_id',
      );
    } catch (e) {
      debugPrint('⚠️ MessagesRepository: ensureMyPresence failed: $e');
    }
  }

  // ─── Active trip guard ────────────────────────────────────────────────────

  /// Checks whether there is an active trip between current user and [otherUserId].
  /// Active statuses: accepted, in_progress, arrived, picked_up.
  Future<bool> hasActiveTripWith(String otherUserId) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return false;
    try {
      final result = await SupabaseService.client
          .from('trips')
          .select('id')
          .inFilter('status', ['pending', 'accepted', 'in_progress', 'arrived', 'picked_up'])
          .or('and(user_id.eq.$userId,driver_id.eq.$otherUserId),and(user_id.eq.$otherUserId,driver_id.eq.$userId)')
          .limit(1);
      return (result as List).isNotEmpty;
    } catch (e) {
      debugPrint('⚠️ MessagesRepository: hasActiveTripWith failed: $e');
      return false;
    }
  }

  // ─── Conversations realtime ───────────────────────────────────────────────

  /// Stream that fires whenever a new message arrives for the current user,
  /// so the conversations list can auto-refresh.
  Stream<void> watchConversations() {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return const Stream.empty();

    final controller = StreamController<void>.broadcast();

    final channel = SupabaseService.client
        .channel('conversations-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'messages',
          callback: (payload) {
            final newRow = payload.newRecord;
            final oldRow = payload.oldRecord;
            final s = newRow['sender_id'] as String? ?? oldRow['sender_id'] as String?;
            final r = newRow['receiver_id'] as String? ?? oldRow['receiver_id'] as String?;
            if (s == userId || r == userId) {
              if (!controller.isClosed) controller.add(null);
            }
          },
        )
        .subscribe();

    controller.onCancel = () {
      SupabaseService.client.removeChannel(channel);
    };

    return controller.stream;
  }
}
