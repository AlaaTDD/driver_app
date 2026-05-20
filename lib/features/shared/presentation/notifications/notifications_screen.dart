import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/constants/app_routes.dart';
import 'package:snapix/features/shared/data/repositories/notifications_repository.dart';
import 'package:snapix/services/supabase_service.dart';
import 'package:snapix/core/widgets/app_button.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  String? _error;
  final _repository = NotificationsRepository();
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _subscribeToStream();
    // Mark all as read when the screen opens
    _repository.markAllAsRead().catchError((_) {});
  }

  void _subscribeToStream() {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _sub = _repository.watchNotifications().listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _notifications = data;
          _isLoading = false;
        });
      },
      onError: (e) {
        debugPrint('❌ NotificationsScreen stream error: $e');
        if (!mounted) return;
        setState(() {
          _error = AppLocalizations.of(context)!.failedLoadNotifications;
          _isLoading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications.map((n) {
          if (n.id == notificationId) return n.copyWith(isRead: true);
          return n;
        }).toList();
      });
    } catch (e) {
      debugPrint('NotificationsScreen: markAsRead error — $e');
    }
  }

  String _formatTime(DateTime createdAt) {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return AppLocalizations.of(context)!.justNow;
    if (diff.inMinutes < 60)
      return AppLocalizations.of(context)!.minutesAgo(diff.inMinutes);
    if (diff.inHours < 24)
      return AppLocalizations.of(context)!.hoursAgo(diff.inHours);
    if (diff.inDays < 7)
      return AppLocalizations.of(context)!.daysAgo(diff.inDays);
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'trip':
        return Icons.directions_car;
      case 'promo':
        return Icons.local_offer;
      case 'system':
        return Icons.info;
      case 'new_message':
        return Icons.chat_bubble_rounded;
      default:
        return Icons.notifications;
    }
  }

  Future<bool> _isDriver() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return false;
      final row = await SupabaseService.client
          .from('users')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return row != null && row['role'] == 'driver';
    } catch (e, st) {
      debugPrint(
          '⚠️ NotificationsScreen: failed to resolve current user role: $e\n$st');
      return false;
    }
  }

  Future<void> _onNotificationTap(NotificationModel notif) async {
    if (!notif.isRead) {
      _markAsRead(notif.id);
    }
    if (notif.type == 'new_message' &&
        notif.referenceId != null &&
        notif.referenceId!.isNotEmpty) {
      final isDriver = await _isDriver();
      final route =
          isDriver ? AppRoutes.driverMessages : AppRoutes.userMessages;
      if (mounted) context.push('$route?otherUserId=${notif.referenceId}');
    } else if (notif.type == 'trip' &&
        notif.referenceId != null &&
        notif.referenceId!.isNotEmpty) {
      final isDriver = await _isDriver();
      final route =
          isDriver ? AppRoutes.driverTripDetails : AppRoutes.userTripDetails;
      if (mounted) context.push('$route?tripId=${notif.referenceId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final lang = Localizations.localeOf(context).languageCode;

    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        title: Text(l.notifications),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_error!,
                          style: TextStyle(color: context.textPrimary)),
                      const SizedBox(height: 16),
                      AppButton(
                        text: l.retry,
                        onPressed: () {
                          _sub?.cancel();
                          _subscribeToStream();
                        },
                        size: AppButtonSize.sm,
                      ),
                    ],
                  ),
                )
              : _notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.notifications_off_outlined,
                              size: 64, color: context.textSecondary),
                          const SizedBox(height: 16),
                          Text(
                            l.notifications,
                            style: TextStyle(
                                color: context.textSecondary, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        final notif = _notifications[index];
                        return _NotificationCard(
                          icon: _getNotificationIcon(notif.type),
                          // Fix #9: use localizedTitle/localizedBody helpers
                          title: notif.localizedTitle(lang),
                          message: notif.localizedBody(lang),
                          time: _formatTime(notif.createdAt),
                          isRead: notif.isRead,
                          onTap: () => _onNotificationTap(notif),
                        );
                      },
                    ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String time;
  final bool isRead;
  final VoidCallback? onTap;

  const _NotificationCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isRead ? context.cardColor : context.elevatedColor,
      child: ListTile(
        leading: Icon(
          icon,
          color: isRead ? context.textSecondary : AppColors.primary,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: context.textPrimary,
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Text(
          message,
          style: TextStyle(color: context.textSecondary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          time,
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 12,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
