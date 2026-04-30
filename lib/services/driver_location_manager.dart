// lib/services/driver_location_manager.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/utils/geohash_helper.dart';

/// Manages driver geohash updates using Geolocator with distance filtering.
///
/// FIX C01: Previously, startTracking() called getPositionStream().listen()
/// but never stored the subscription. stopTracking() created a NEW stream
/// and immediately cancelled it — leaving the original stream running forever.
/// This caused permanent GPS drain and battery death.
class DriverLocationManager {
  static final DriverLocationManager _instance = DriverLocationManager._internal();
  factory DriverLocationManager() => _instance;
  DriverLocationManager._internal();

  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  String? _currentGeohash;

  // FIX C01: Store the subscription so we can actually cancel it
  StreamSubscription<Position>? _positionSubscription;

  String? get currentGeohash => _currentGeohash;

  /// Whether tracking is currently active
  bool get isTracking => _positionSubscription != null;

  Future<void> startTracking(Function(String) onGeohashChanged) async {
    // Guard: cancel existing subscription before starting new one
    await _positionSubscription?.cancel();

    _positionSubscription = _geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (Position position) {
        final newGeohash = GeohashHelper.encode(
          position.latitude,
          position.longitude,
        );

        if (_currentGeohash != newGeohash) {
          _currentGeohash = newGeohash;
          onGeohashChanged(newGeohash);
        }
      },
      onError: (e) {
        debugPrint('❌ DriverLocationManager: Stream error: $e');
      },
    );

    debugPrint('📍 DriverLocationManager: Tracking started');
  }

  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _currentGeohash = null;
    debugPrint('📍 DriverLocationManager: Tracking stopped');
  }
}
