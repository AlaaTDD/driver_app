import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:snapix/core/utils/app_logger.dart';

/// Thin wrapper around [GoogleMapController] that de-duplicates animate calls
/// and provides common camera utilities.
class AppMapController {
  GoogleMapController? _ctrl;
  double? _lastLat;
  double? _lastLng;
  LatLng? _lastPosition;

  LatLng? get lastPosition => _lastPosition;

  /// Pass directly to AppGoogleMap.onMapCreated
  void onMapCreated(GoogleMapController controller) {
    _ctrl = controller;
  }

  /// Animate the camera, skipping duplicate positions.
  Future<void> animateTo({
    required double lat,
    required double lng,
    double zoom = 15.0,
  }) async {
    if (_ctrl == null) return;
    if (_lastLat == lat && _lastLng == lng) return;
    _lastLat = lat;
    _lastLng = lng;
    _lastPosition = LatLng(lat, lng);
    try {
      await _ctrl!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: zoom),
        ),
      );
    } catch (e, st) {
      AppLogger.warning('AppMapController: animateCamera failed: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
    }
  }

  /// Fit the camera to a set of points.
  Future<void> fitPoints(
    Iterable<LatLng> points, {
    double padding = 96,
  }) async {
    if (_ctrl == null) return;
    await _ctrl!.animateCamera(
      CameraUpdate.newLatLngBounds(
        _boundsFor(points),
        padding,
      ),
    );
  }

  /// Reset last-position tracking (useful before recenter).
  void resetLastPosition() {
    _lastLat = null;
    _lastLng = null;
  }

  void dispose() {
    _ctrl?.dispose();
    _ctrl = null;
  }

  static LatLngBounds _boundsFor(Iterable<LatLng> points) {
    final list = points.toList();
    var minLat = list.first.latitude;
    var maxLat = list.first.latitude;
    var minLng = list.first.longitude;
    var maxLng = list.first.longitude;
    for (final p in list.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
