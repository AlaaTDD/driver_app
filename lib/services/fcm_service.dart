
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/widgets.dart';

import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';
import '../core/constants/env_constants.dart';
import '../core/overlay/isolate_manager.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  developer.log('Handling a background message: ${message.messageId}');

  // 1. Ensure Flutter bindings are initialized in this background isolate
  try {
    WidgetsFlutterBinding.ensureInitialized();
  } catch (e) {
    developer.log('WidgetsFlutterBinding init error: $e');
  }

  // 2. Ensure Firebase is initialized
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (e) {
    developer.log('Firebase init error: $e');
  }

  // 3. Initialize Local Notifications for this isolate so fallback works
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  // 4. Load Supabase env
  try {
    Supabase.instance.client.auth.currentSession;
  } catch (_) {
    try {
      await dotenv.load(fileName: '.env');
      await Supabase.initialize(
        url: EnvConstants.supabaseUrl,
        anonKey: EnvConstants.supabaseAnonKey,
      );
    } catch (e) {
      developer.log('Background Supabase init error: $e');
    }
  }

  await handleRideOfferNotification(message.data);
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
      _handleForegroundMessage(message);
    });

    
    _messaging.onTokenRefresh.listen((newToken) {
      _onTokenRefresh(newToken);
    });
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

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final type = message.data['type'] ?? message.data['notification_type'];

    if (type == 'ride_offer') {
      
      await handleRideOfferNotification(message.data);
      return;
    }

    
    await _showLocalNotification(message);
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
