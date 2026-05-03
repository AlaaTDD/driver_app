
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';









class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  static LocationService get instance => _instance;
  LocationService._internal();

  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;

  

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

  

  
  
  
  
  
  Future<Position> getCurrentLocation() async {
    
    final isEnabled = await _geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      
      final last = await _geolocator.getLastKnownPosition();
      if (last != null) return last;
      
      debugPrint('⚠️ LocationService: GPS disabled. Using fallback location.');
      return Position(
        longitude: 31.2357,
        latitude: 30.0444,
        timestamp: DateTime.now(),
        accuracy: 100.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }

    try {
      
      return await _geolocator
          .getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          )
          .timeout(const Duration(seconds: 12));
    } catch (primaryError) {
      
      final last = await _geolocator.getLastKnownPosition();
      if (last != null) return last;

      
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
        
        debugPrint('❌ LocationService: All 3 fallbacks failed. Last error: $e');
        rethrow;
      }
    }
  }

  

  
  
  
  Stream<Position> getLocationStream() async* {
    final isEnabled = await _geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      debugPrint('⚠️ LocationService (Stream): GPS disabled. Emitting fallback location.');
      yield* Stream.periodic(const Duration(seconds: 5), (_) => Position(
        longitude: 31.2357,
        latitude: 30.0444,
        timestamp: DateTime.now(),
        accuracy: 100.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      ));
      return;
    }

    yield* _geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }
}
