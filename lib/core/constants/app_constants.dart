import 'package:google_maps_flutter/google_maps_flutter.dart';

/// ══════════════════════════════════════════════════════════════
/// AppConstants — ثوابت التطبيق المركزية
///
/// مقسَّمة إلى أقسام واضحة:
///   Storage buckets · Table names · Message types ·
///   Trip statuses · Timeouts · Animations · Pagination ·
///   File limits · Map defaults
/// ══════════════════════════════════════════════════════════════
class AppConstants {
  AppConstants._();

  // ─── Storage buckets ─────────────────────────────────────────
  static const String chatMediaBucket    = 'chat_media';
  static const String profilePhotosBucket = 'profile_photos';
  static const String documentsBucket    = 'documents';

  // ─── Map defaults ─────────────────────────────────────────────
  /// مركز الخريطة الافتراضي — يُستبدل من app_config عند التشغيل
  static const LatLng fallbackMapCenter = LatLng(24.7136, 46.6753);
  static LatLng defaultMapCenter = fallbackMapCenter;

  static void setDefaultMapCenter(LatLng center) {
    defaultMapCenter = center;
  }

  // ─── Table names ─────────────────────────────────────────────
  static const String tableMessages      = 'messages';
  static const String tableSupportMessages = 'support_messages';
  static const String tableNotifications = 'notifications';
  static const String tableUserPresence  = 'user_presence';
  static const String tableTrips         = 'trips';
  static const String tableUsers         = 'users';
  static const String tableWallets       = 'wallets';
  static const String tableTransactions  = 'wallet_transactions';

  // ─── Message types ───────────────────────────────────────────
  static const String messageTypeText     = 'text';
  static const String messageTypeImage    = 'image';
  static const String messageTypeLocation = 'location';
  static const String messageTypeVoice    = 'voice';

  // ─── Trip statuses ───────────────────────────────────────────
  /// حالات الرحلة النشطة (مستخدمة لحراسة الـ chat وغيره)
  static const List<String> activeTripStatuses = [
    'scheduled',
    'searching',
    'accepted',
    'driver_arriving',
    'in_progress',
  ];

  /// حالات الرحلة المكتملة أو الملغاة
  static const List<String> terminalTripStatuses = [
    'completed',
    'cancelled',
    'rejected',
  ];

  // ─── Timeouts ────────────────────────────────────────────────
  static const Duration apiTimeout      = Duration(seconds: 30);
  static const Duration locationTimeout = Duration(seconds: 10);
  static const Duration socketTimeout   = Duration(seconds: 15);
  /// مهلة انتظار السائق لقبول الرحلة
  static const Duration offerTimeout    = Duration(seconds: 60);

  // ─── Animation durations ─────────────────────────────────────
  static const Duration animShort  = Duration(milliseconds: 150);
  static const Duration animNormal = Duration(milliseconds: 300);
  static const Duration animLong   = Duration(milliseconds: 500);
  static const Duration animPage   = Duration(milliseconds: 350);

  // ─── Pagination ──────────────────────────────────────────────
  static const int pageSize     = 20;
  static const int chatPageSize = 30;
  static const int tripsPageSize = 15;

  // ─── File limits ─────────────────────────────────────────────
  static const int maxImageSizeMB = 5;
  static const int maxFileSizeMB  = 10;
  static const int maxImageSizeBytes = maxImageSizeMB * 1024 * 1024;
  static const int maxFileSizeBytes  = maxFileSizeMB  * 1024 * 1024;

  // ─── Map ─────────────────────────────────────────────────────
  static const double defaultMapZoom      = 14.0;
  static const double streetLevelZoom     = 17.0;
  static const double cityLevelZoom       = 12.0;
  static const double driverTrackingZoom  = 15.5;
}
