
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/utils/geohash_helper.dart';







class DriverLocationManager {
  static final DriverLocationManager _instance = DriverLocationManager._internal();
  factory DriverLocationManager() => _instance;
  DriverLocationManager._internal();

  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  String? _currentGeohash;

  
  StreamSubscription<Position>? _positionSubscription;

  String? get currentGeohash => _currentGeohash;

  
  bool get isTracking => _positionSubscription != null;

  Future<void> startTracking(Function(String) onGeohashChanged) async {
    
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
