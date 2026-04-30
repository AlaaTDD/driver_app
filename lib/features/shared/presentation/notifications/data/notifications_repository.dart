// lib/features/shared/presentation/notifications/data/notifications_repository.dart
import '../../../../../core/models/notification_model.dart';
import '../../../../../services/supabase_service.dart';

/// Repository that encapsulates all Supabase calls for notifications.
/// This separates UI from data sources (Clean Architecture).
class NotificationsRepository {
  /// Load all notifications for the current user, returns type-safe models.
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

  /// Mark a notification as read.
  Future<void> markAsRead(String notificationId) async {
    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Mark all notifications as read for the current user.
  Future<void> markAllAsRead() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    await SupabaseService.client
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }

  /// Delete a notification.
  Future<void> deleteNotification(String notificationId) async {
    await SupabaseService.client
        .from('notifications')
        .delete()
        .eq('id', notificationId);
  }

  /// Real-time stream for unread notifications count.
  /// Requires `notifications` table to be in the supabase_realtime publication.
  Stream<int> getUnreadCountStream(String userId) {
    return SupabaseService.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.where((r) => r['is_read'] == false).length);
  }
}
