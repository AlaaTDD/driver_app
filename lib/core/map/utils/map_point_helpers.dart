import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Shared helpers for validating and comparing map points.
///
/// Previously duplicated across:
/// - user/trip_details_screen.dart
/// - driver/trip_details_screen.dart
/// - user/tracking_screen.dart
class MapPointHelpers {
  MapPointHelpers._();

  /// Returns a [LatLng] if [lat] and [lng] are valid (non-null, non-zero, finite).
  static LatLng? tripPoint(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (lat == 0.0 && lng == 0.0) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    return LatLng(lat, lng);
  }

  /// Returns `true` when two points are within ~5 m of each other.
  static bool samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00005 &&
        (a.longitude - b.longitude).abs() < 0.00005;
  }
}
