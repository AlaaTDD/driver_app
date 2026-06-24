import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Calculates the bearing between two geographic points.
/// Replaces the 15-line `_calculateBearing` copied in multiple screens.
class AppMapBearing {
  AppMapBearing._();

  static double calculate(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final dLng = (to.longitude - from.longitude) * math.pi / 180;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }
}
