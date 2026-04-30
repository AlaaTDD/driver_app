// lib/features/shared/presentation/messages/data/messages_repository.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../../core/models/message_model.dart';
import '../../../../../services/supabase_service.dart';

/// Repository that encapsulates all Supabase calls for messages.
/// This separates UI from data sources (Clean Architecture).
class MessagesRepository {
  /// Load all messages for a trip, returns type-safe [MessageModel] list.
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

  /// Load support messages for current user.
  Future<List<Map<String, dynamic>>> loadSupportMessages() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final data = await SupabaseService.client
        .from('support_messages')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: true);

    return (data as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Real-time subscription to trip messages.
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

  /// Send a trip message with correct schema columns.
  ///
  /// SCHEMA FIX: Uses `content` (correct column) instead of `message`.
  /// SCHEMA FIX: Now includes `receiver_id` (required NOT NULL column).
  Future<void> sendTripMessage(String tripId, String text) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    // Resolve receiver_id from trip participants
    final receiverId = await _resolveReceiverId(tripId, userId);
    if (receiverId == null) {
      debugPrint('⚠️ MessagesRepository: Cannot determine receiver for trip $tripId');
      return;
    }

    await SupabaseService.client.from('messages').insert({
      'trip_id': tripId,
      'sender_id': userId,
      'receiver_id': receiverId,
      'content': text, // FIXED: was 'message', schema column is 'content'
    });
  }

  /// Send a support message.
  Future<void> sendSupportMessage(String text) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client.from('support_messages').insert({
      'user_id': userId,
      'message': text, // support_messages schema DOES use 'message'
      'sender_role': 'user',
    });
  }

  /// Fetch trip participants (user_id and driver_id).
  Future<Map<String, dynamic>?> fetchTripParticipants(String tripId) async {
    return await SupabaseService.client
        .from('trips')
        .select('user_id, driver_id')
        .eq('id', tripId)
        .maybeSingle();
  }

  /// Fetch user name by ID.
  Future<String?> fetchUserName(String userId) async {
    final data = await SupabaseService.client
        .from('users')
        .select('name')
        .eq('id', userId)
        .maybeSingle();
    return data?['name'] as String?;
  }

  /// Fetch current user's name.
  Future<String?> fetchCurrentUserName() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return null;
    return fetchUserName(userId);
  }

  /// Create a notification record.
  Future<void> createNotification({
    required String receiverId,
    required String title,
    required String titleAr,
    required String message,
    required String bodyAr,
    required String type,
    required String? referenceId,
  }) async {
    await SupabaseService.client.from('notifications').insert({
      'user_id': receiverId,
      'title': title,
      'title_ar': titleAr,
      'message': message,
      'body_ar': bodyAr,
      'type': type,
      'reference_id': referenceId,
    });
  }

  /// Send FCM push notification via Edge Function.
  Future<void> sendFcmPush({
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
      debugPrint('MessagesRepository: send-fcm error — $e');
    }
  }

  /// Sends a trip message and triggers a notification + FCM push to the receiver.
  Future<void> sendTripMessageWithNotification({
    required String tripId,
    required String text,
    required String senderName,
    required String Function(String name) newMessageFrom,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    // 1. Save message (now correctly resolves receiver_id internally)
    await sendTripMessage(tripId, text);

    // 2. Determine receiver
    final tripData = await fetchTripParticipants(tripId);
    if (tripData == null) return;

    final receiverId = (tripData['user_id'] == userId)
        ? tripData['driver_id']
        : tripData['user_id'];
    if (receiverId == null) return;

    // 3. Create notification
    final title = newMessageFrom(senderName);
    await createNotification(
      receiverId: receiverId,
      title: title,
      titleAr: title,
      message: text,
      bodyAr: text,
      type: 'new_message', // FIXED: use notification type from schema constraint
      referenceId: tripId,
    );

    // 4. Send FCM push
    await sendFcmPush(
      userId: receiverId,
      title: title,
      body: text,
      data: {'type': 'new_message', 'tripId': tripId},
    );
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  /// Resolves the receiver_id for a trip message.
  /// If the sender is the user, receiver is the driver; vice versa.
  Future<String?> _resolveReceiverId(String tripId, String senderId) async {
    final tripData = await fetchTripParticipants(tripId);
    if (tripData == null) return null;

    final tripUserId = tripData['user_id'] as String?;
    final tripDriverId = tripData['driver_id'] as String?;

    if (senderId == tripUserId) return tripDriverId;
    if (senderId == tripDriverId) return tripUserId;
    return null;
  }
}
