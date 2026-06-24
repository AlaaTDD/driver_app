import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:snapix/core/models/notification_model.dart';
import 'package:snapix/core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class NotificationsRepository {
  Future<List<NotificationModel>> loadNotifications() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return [];

    final data = await SupabaseService.client
        .from('notifications')
        .select('id, user_id, title, body, type, is_read, data, created_at')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<void> markAsRead(String notificationId) async {
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
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

    Future<void> fetchCount() async {
      try {
        final result = await SupabaseService.client
            .rpc('get_unread_count', params: {'p_user_id': userId});
        controller.add((result as int?) ?? 0);
      } catch (e) {
        controller.add(0);
      }
    }

    fetchCount();

    final channel = SupabaseService.client
        .channel('unread-count-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          callback: (_) => fetchCount(),
        )
        .subscribe();

    controller.onCancel = () {
      SupabaseService.client.removeChannel(channel);
    };

    return controller.stream;
  }

  /// Realtime stream of all notifications for current user.
  /// Auto-refreshes when notifications table changes.
  Stream<List<NotificationModel>> watchNotifications() {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return const Stream.empty();

    final controller = StreamController<List<NotificationModel>>.broadcast();

    Future<void> fetchAll() async {
      try {
        final list = await loadNotifications();
        if (!controller.isClosed) controller.add(list);
      } catch (e, st) {
        AppLogger.warning('NotificationsRepository: fetchAll failed: $e\n$st');
      }
    }

    fetchAll();

    final channel = SupabaseService.client
        .channel('notifications-list-$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (_) => fetchAll(),
        )
        .subscribe();

    controller.onCancel = () {
      SupabaseService.client.removeChannel(channel);
    };

    return controller.stream;
  }
}
