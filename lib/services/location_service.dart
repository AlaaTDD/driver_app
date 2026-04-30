// lib/services/location_service.dart
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Singleton location service with robust error handling and fallback chain.
///
/// Priority chain for getting a position:
///   1. getCurrentPosition (high accuracy, 10s timeout)
///   2. getLastKnownPosition (instant, may be slightly stale)
///   3. getPositionStream first emission (last resort)
///
/// This prevents the app from hanging when GPS takes too long.
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  static LocationService get instance => _instance;
  LocationService._internal();

  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;

  // ─── Permission ───────────────────────────────────────────────────────────

  Future<bool> hasPermission() async {
    final perm = await _geolocator.checkPermission();
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  Future<bool> requestPermission() async {
    final permission = await _geolocator.requestPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ─── One-shot Location ────────────────────────────────────────────────────

  /// Get current position with a 3-level fallback chain to avoid hanging:
  ///
  /// 1. Try getCurrentPosition (10s timeout, high accuracy)
  /// 2. Fall back to last known position (instant)
  /// 3. Rethrow if both fail
  Future<Position> getCurrentLocation() async {
    // First check if location services are enabled at all
    final isEnabled = await _geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      // Services off → immediately try last known (may still be cached)
      final last = await _geolocator.getLastKnownPosition();
      if (last != null) return last;
      throw Exception('Location services are disabled.');
    }

    try {
      // Primary: high-accuracy GPS with 10s timeout
      return await _geolocator
          .getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          )
          .timeout(const Duration(seconds: 12));
    } catch (primaryError) {
      // Fallback 1: last known position (instant)
      final last = await _geolocator.getLastKnownPosition();
      if (last != null) return last;

      // Fallback 2: reduced-accuracy position (faster fix)
      try {
        return await _geolocator
            .getCurrentPosition(
              locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.reduced,
                timeLimit: Duration(seconds: 8),
              ),
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        // All fallbacks failed — log the chain failure
        debugPrint('❌ LocationService: All 3 fallbacks failed. Last error: $e');
        rethrow;
      }
    }
  }

  // ─── Continuous Stream ────────────────────────────────────────────────────

  /// Returns a stream of position updates.
  /// - accuracy: high
  /// - distanceFilter: 10m (don't spam for tiny movements)
  Stream<Position> getLocationStream() {
    return _geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}
