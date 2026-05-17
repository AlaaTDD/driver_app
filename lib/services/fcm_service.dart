
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';

import 'dart:developer' as developer;
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import '../core/constants/env_constants.dart';
import '../../firebase_options.dart';
import '../features/ride_offer/overlay/ride_offer_overlay.dart';
import '../core/router/app_router.dart';
import '../core/constants/app_routes.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('🔥 FCM BACKGROUND: Message received! ID: ${message.messageId}');
  // Do not initialize Supabase or UI in background isolate
}

class FCMService {
  static final FCMService _instance = FCMService._internal();
  factory FCMService() => _instance;
  FCMService._internal();

  bool get _isInitialized => Firebase.apps.isNotEmpty;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

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
    const initSettings = InitializationSettings(android: androidInit, iOS: darwinInit);

    
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel', 
      'High Importance Notifications', 
      description: 'This channel is used for important notifications.', 
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
      developer.log('🔥 FCM FOREGROUND: Message received! ID: ${message.messageId}');
      developer.log('🔥 FCM FOREGROUND: Data payload: ${message.data}');
      _handleForegroundMessage(message);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      developer.log('🔥 FCM OPENED APP: Message clicked! ID: ${message.messageId}');
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
      developer.log('🔥 FCM INITIAL TOKEN: $token');
      if (token != null) {
        await _onTokenRefresh(token);
      }
    } catch (e) {
      developer.log('🔥 FCM INITIAL TOKEN ERROR: $e');
    }
  }

  
  Future<void> _onTokenRefresh(String newToken) async {
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId != null) {
        await SupabaseService.client
            .from('users')
            .update({'fcm_token': newToken})
            .eq('id', userId);
        developer.log('FCMService: Token refreshed and stored for $userId');
      }
    } catch (e) {
      developer.log('FCMService: Failed to store refreshed token: $e');
    }
  }

  final Set<String> _handledMessageIds = {};

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final messageId = message.messageId;
    if (messageId != null) {
      if (_handledMessageIds.contains(messageId)) {
        developer.log('🔥 FCM FOREGROUND: Duplicate message ignored: $messageId');
        return;
      }
      _handledMessageIds.add(messageId);
      // Clean up old message IDs to prevent memory leaks
      if (_handledMessageIds.length > 100) {
        _handledMessageIds.clear();
      }
    }

    final type = message.data['type'] ?? message.data['notification_type'];

    if (type == 'ride_offer') {
      await handleRideOfferNotification(message.data);
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
        final referenceId = message.data['referenceId'] ?? message.data['tripId'];
        if (referenceId != null && referenceId.toString().isNotEmpty) {
          final isDriver = await _isDriver();
          final route = isDriver ? AppRoutes.driverTripDetails : AppRoutes.userTripDetails;
          router.go('$route?tripId=$referenceId');
        }
        break;
      case 'ride_offer':
        developer.log('🔥 FCM OPENED APP: User tapped ride_offer notification!');
        // Typically you'd navigate to the trip details page here.
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
    } catch (_) {
      return false;
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'taxi_app_channel',
      'Taxi App Notifications',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: darwinDetails);

    await _localNotifications.show(
      notification.hashCode,
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
