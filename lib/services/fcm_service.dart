import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'dart:developer' as developer;
import 'dart:io';

import 'supabase_service.dart';
import '../core/router/app_router.dart';
import '../core/constants/app_routes.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('FCM BACKGROUND: Message received! ID: ${message.messageId}');
  // Do not initialize Supabase or UI in background isolate
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  // Channel configuration
  static const String channelId = 'high_importance_channel';
  static const String channelName = 'Snapix Notifications';
  static const String channelDescription =
      'Important app notifications and updates.';

  Future<void> Function(Map<String, dynamic>)? _onRideOffer;
  void setRideOfferHandler(Future<void> Function(Map<String, dynamic>) h) =>
      _onRideOffer = h;

  bool get _isInitialized => Firebase.apps.isNotEmpty;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    if (!_isInitialized) return;
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings =
        InitializationSettings(android: androidInit, iOS: darwinInit);

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    );

    final androidFlutterLocalNotificationsPlugin =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidFlutterLocalNotificationsPlugin != null) {
      await androidFlutterLocalNotificationsPlugin
          .createNotificationChannel(channel);
    }

    await _localNotifications.initialize(initSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      developer
          .log('FCM FOREGROUND: Message received! ID: ${message.messageId}');
      developer.log('FCM FOREGROUND: Data payload: ${message.data}');
      _handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer
          .log('FCM OPENED APP: Message clicked! ID: ${message.messageId}');
      _handleMessageOpen(message);
    });

    _messaging.onTokenRefresh.listen((newToken) {
      _onTokenRefresh(newToken);
    });

    try {
      if (Platform.isIOS) {
        String? apnsToken = await _messaging.getAPNSToken();
        if (apnsToken == null) {
          developer.log('APNS token is null, waiting 3 seconds...');
          await Future<void>.delayed(const Duration(seconds: 3));
          apnsToken = await _messaging.getAPNSToken();
        }
        developer.log('APNS Token: $apnsToken');
      }

      final token = await _messaging.getToken();
      developer.log('FCM INITIAL TOKEN: $token');
      if (token != null) {
        await _onTokenRefresh(token);
      }
    } catch (e) {
      developer.log('FCM INITIAL TOKEN ERROR: $e');
    }
  }

  Future<void> _onTokenRefresh(String newToken) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId != null) {
        await SupabaseService.client
            .from('users')
            .update({'fcm_token': newToken}).eq('id', userId);
        developer.log('FCMService: Token refreshed and stored for $userId');
      }
    } catch (e, st) {
      developer.log(
        'FCMService: Failed to store refreshed token',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> clearFcmToken() async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;

      await SupabaseService.client
          .from('users')
          .update({'fcm_token': null}).eq('id', userId);
      developer.log('FCMService: Cleared FCM token for $userId');
    } catch (e, st) {
      developer.log(
        'FCMService: Failed to clear FCM token',
        error: e,
        stackTrace: st,
      );
    }
  }

  final List<String> _handledMessageIds = [];

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final messageId = message.messageId;
    if (messageId != null) {
      if (_handledMessageIds.contains(messageId)) {
        developer.log('FCM FOREGROUND: Duplicate message ignored: $messageId');
        return;
      }
      if (_handledMessageIds.length >= 100) {
        _handledMessageIds.removeAt(0);
      }
      _handledMessageIds.add(messageId);
    }

    final type = message.data['type'] ?? message.data['notification_type'];

    if (type == 'ride_offer') {
      if (_onRideOffer != null) {
        await _onRideOffer!(message.data);
      }
      return;
    }

    // Fallback to local notification for other types
    await _showLocalNotification(message);
  }

  Future<void> _handleMessageOpen(RemoteMessage message) async {
    final type = message.data['type'] ?? message.data['notification_type'];
    final router = AppRouter.routerInstance;

    switch (type) {
      case 'new_message':
        final senderId = message.data['senderId'];
        final tripId = message.data['tripId'];
        // Determine role to route to the correct messages screen
        final messagesRoute = await _getMessagesRouteForCurrentUser();
        if (tripId != null && tripId.toString().isNotEmpty) {
          router.go('$messagesRoute?tripId=$tripId');
        } else if (senderId != null && senderId.toString().isNotEmpty) {
          router.go('$messagesRoute?otherUserId=$senderId');
        }
        break;
      case 'trip':
        final referenceId =
            message.data['referenceId'] ?? message.data['tripId'];
        if (referenceId != null && referenceId.toString().isNotEmpty) {
          final isDriver = await _isDriver();
          final route = isDriver
              ? AppRoutes.driverTripDetails
              : AppRoutes.userTripDetails;
          router.go('$route?tripId=$referenceId');
        }
        break;
      case 'ride_offer':
        final tripId = message.data['trip_id'] ?? message.data['tripId'];
        router.go(AppRoutes.driverHome);
        if (tripId != null) {
          router.go('${AppRoutes.driverTripDetails}?tripId=$tripId');
        }
        break;
    }
  }

  /// Returns the correct messages route based on the current user's role.
  Future<String> _getMessagesRouteForCurrentUser() async {
    final isDriver = await _isDriver();
    return isDriver ? AppRoutes.driverMessages : AppRoutes.userMessages;
  }

  /// Checks if the current authenticated user has role='driver'.
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
      developer.log(
        'FCMService: Failed to resolve current user role',
        error: e,
        stackTrace: st,
      );
      return false;
    }
  }

  int _notificationCounter = 0;

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails();
    const details =
        NotificationDetails(android: androidDetails, iOS: darwinDetails);

    await _localNotifications.show(
      _notificationCounter++,
      notification.title,
      notification.body,
      details,
    );
  }

  Future<String?> getToken() async {
    if (!_isInitialized) return null;
    return await _messaging.getToken();
  }

  Future<void> subscribeToTopic(String topic) async {
    if (!_isInitialized) return;
    await _messaging.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    if (!_isInitialized) return;
    await _messaging.unsubscribeFromTopic(topic);
  }
}
