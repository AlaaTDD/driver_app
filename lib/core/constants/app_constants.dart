import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppConstants {
  // Storage buckets
  static const String chatMediaBucket = 'chat_media';

  // Default map center, overridden at startup from app_config when available.
  static const LatLng fallbackMapCenter = LatLng(24.7136, 46.6753);
  static LatLng defaultMapCenter = fallbackMapCenter;

  static void setDefaultMapCenter(LatLng center) {
    defaultMapCenter = center;
  }

  // Table names
  static const String tableMessages = 'messages';
  static const String tableSupportMessages = 'support_messages';
  static const String tableNotifications = 'notifications';
  static const String tableUserPresence = 'user_presence';
  static const String tableTrips = 'trips';
  static const String tableUsers = 'users';

  // Message types
  static const String messageTypeText = 'text';
  static const String messageTypeImage = 'image';
  static const String messageTypeLocation = 'location';
  static const String messageTypeVoice = 'voice';

  // Active trip statuses (used for chat guards)
  static const List<String> activeTripStatuses = [
    'searching',
    'accepted',
    'in_progress',
  ];
}
