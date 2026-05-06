
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/models/notification_model.dart';
import '../../../../../services/supabase_service.dart';



class NotificationsRepository {
  
  Future<List<NotificationModel>> loadNotifications() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final data = await SupabaseService.client
        .from('notifications')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  
  Future<void> markAsRead(String notificationId) async {
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  
  Future<void> markAllAsRead() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  
  Future<void> deleteNotification(String notificationId) async {
    await SupabaseService.client
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }

  
  
  Stream<int> getUnreadCountStream(String userId) {
    // Use RPC with realtime trigger for efficiency instead of loading all rows
    final controller = StreamController<int>.broadcast();

    Future<void> _fetch() async {
      try {
        final result = await SupabaseService.client
            .rpc('get_unread_count', params: {'p_user_id': userId});
        controller.add((result as int?) ?? 0);
      } catch (e) {
        controller.add(0);
      }
    }

    _fetch();

    final channel = SupabaseService.client
        .channel('unread-count-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => _fetch(),
        )
        .subscribe();

    controller.onCancel = () {
      SupabaseService.client.removeChannel(channel);
    };

    return controller.stream;
  }
}
