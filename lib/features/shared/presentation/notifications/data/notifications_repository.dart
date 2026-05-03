
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
    return SupabaseService.client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .map((rows) => rows.where((r) => r['is_read'] == false).length);
  }
}
