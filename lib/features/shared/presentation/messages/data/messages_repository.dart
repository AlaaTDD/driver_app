
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../../../core/models/message_model.dart';
import '../../../../../services/supabase_service.dart';



class MessagesRepository {
  
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

  
  
  
  
  Future<void> sendTripMessage(String tripId, String text) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    
    final receiverId = await _resolveReceiverId(tripId, userId);
    if (receiverId == null) {
      debugPrint('⚠️ MessagesRepository: Cannot determine receiver for trip $tripId');
      return;
    }

    await SupabaseService.client.from('messages').insert({
      'trip_id': tripId,
      'sender_id': userId,
      'receiver_id': receiverId,
      'content': text, 
    });
  }

  
  Future<void> sendSupportMessage(String text) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client.from('support_messages').insert({
      'user_id': userId,
      'message': text, 
      'sender_role': 'user',
    });
  }

  
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

  
  Future<void> sendTripMessageWithNotification({
    required String tripId,
    required String text,
    required String senderName,
    required String Function(String name) newMessageFrom,
  }) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    
    await sendTripMessage(tripId, text);

    
    final tripData = await fetchTripParticipants(tripId);
    if (tripData == null) return;

    final receiverId = (tripData['user_id'] == userId)
        ? tripData['driver_id']
        : tripData['user_id'];
    if (receiverId == null) return;

    
    final title = newMessageFrom(senderName);
    await createNotification(
      receiverId: receiverId,
      title: title,
      titleAr: title,
      message: text,
      bodyAr: text,
      type: 'new_message', 
      referenceId: tripId,
    );

    
    await sendFcmPush(
      userId: receiverId,
      title: title,
      body: text,
      data: {'type': 'new_message', 'tripId': tripId},
    );
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
}
