
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:ui';

import '../../features/ride_offer/data/models/ride_offer_model.dart';
import '../../features/ride_offer/overlay/ride_offer_overlay.dart';

/// يدير التواصل بين الـ Overlay Isolate والـ Main App Isolate
/// عبر IsolateNameServer المدمج في Dart
class IsolateManager {
  // الاسم المسجّل للـ Port في الـ IsolateNameServer
  // يجب أن يكون نفس الاسم في الطرفين (Main App + Overlay)
  static const String portName = 'snapix_overlay_port';

  /// يسجّل الـ Main App Port عشان يستقبل رسائل من الـ Overlay
  /// يُستدعى مرة واحدة في main()
  static bool registerPortWithName(SendPort port) {
    // احذف القديم لو موجود عشان نتجنب conflict
    removePortNameMapping(portName);
    return IsolateNameServer.registerPortWithName(port, portName);
  }

  /// الـ Overlay يستخدم ده عشان يبعت رسائل للـ Main App
  /// ممكن يرجع null لو الـ Main App مش شاغل (app مغلق تماماً)
  static SendPort? lookupPortByName() {
    return IsolateNameServer.lookupPortByName(portName);
  }

  /// إزالة تسجيل الـ Port (عند إغلاق التطبيق)
  static bool removePortNameMapping(String name) {
    return IsolateNameServer.removePortNameMapping(name);
  }
}

/// Handles incoming ride-offer FCM notifications (foreground & background)
Future<void> handleRideOfferNotification(Map<String, dynamic> data) async {
  try {
    final type = data['type'] ?? data['notification_type'];
    if (type != 'ride_offer') {
      return;
    }

    final offerData = data['data'] != null
        ? jsonDecode(data['data'] as String) as Map<String, dynamic>
        : data;

    final offer = RideOfferModel.fromPayload(offerData);
    if (offer == null) {
      developer.log('handleRideOfferNotification: failed to parse offer');
      return;
    }

    await showRideOfferOverlay(offer);
  } catch (e, st) {
    developer.log(
      'handleRideOfferNotification error',
      error: e,
      stackTrace: st,
    );
  }
}
