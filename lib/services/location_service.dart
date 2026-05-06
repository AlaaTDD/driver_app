import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';







class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  static LocationService get instance => _instance;
  LocationService._internal();

  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  StreamSubscription<Position>? _tripTrackingSub;
  String? _activeTripDriverId;
  RealtimeChannel? _broadcastChannel;
  Timer? _heartbeatTimer;
  double? _lastLat;
  double? _lastLng;
  double? _lastHeading;

  

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

  

  
  
  
  Stream<Position>? _broadcastStream;

  Stream<Position> getLocationStream() {
    _broadcastStream ??= _createLocationStream().asBroadcastStream();
    return _broadcastStream!;
  }

  Stream<Position> _createLocationStream() async* {
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

  void startTripTracking(String driverId) {
    if (_tripTrackingSub != null) return;
    _activeTripDriverId = driverId;
    debugPrint('📍 LocationService: Starting global trip tracking for driver $driverId');
    
    // Create a dedicated broadcast channel so the user can get REAL-TIME updates
    // even faster than the DB stream (no RLS issues with broadcast)
    _broadcastChannel?.unsubscribe();
    _broadcastChannel = SupabaseService.client.channel('trip-tracking-$driverId');
    _broadcastChannel!.subscribe((status, [error]) {
      debugPrint('📍 LocationService: Broadcast channel status=$status');
      // Once subscribed, immediately broadcast last known position (if any) so user gets it instantly
      if (_lastLat != null) {
        // Send the last known position immediately to any new subscribers
        _broadcastChannel?.sendBroadcastMessage(
          event: 'location_update',
          payload: {'lat': _lastLat, 'lng': _lastLng, 'heading': _lastHeading ?? 0.0},
        );
      }
    });
    
    // Heartbeat: broadcast every 5s so any late subscriber gets the driver's position
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_lastLat != null && _broadcastChannel != null) {
        _broadcastChannel!.sendBroadcastMessage(
          event: 'location_update',
          payload: {'lat': _lastLat, 'lng': _lastLng, 'heading': _lastHeading ?? 0.0},
        );
      }
    });
    
    _tripTrackingSub = getLocationStream().listen((pos) async {
      // Save last known position for heartbeat
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      _lastHeading = pos.heading;
      
      // 1) Broadcast via realtime channel (instant, bypasses RLS)
      try {
        await _broadcastChannel?.sendBroadcastMessage(
          event: 'location_update',
          payload: {
            'lat': pos.latitude,
            'lng': pos.longitude,
            'heading': pos.heading,
          },
        );
      } catch (e) {
        debugPrint('⚠️ LocationService: broadcast failed: $e');
      }

      // 2) Also write to DB so it persists (best-effort)
      try {
        final geohash = _encodeGeohash(pos.latitude, pos.longitude);
        final geohash5 = geohash.length > 5 ? geohash.substring(0, 5) : geohash;
        await SupabaseService.client.rpc('upsert_driver_location', params: {
          'p_driver_id': driverId,
          'p_lat': pos.latitude,
          'p_lng': pos.longitude,
          'p_heading': pos.heading,
          'p_geohash': geohash,
          'p_geohash5': geohash5,
        });
      } catch (e) {
        debugPrint('⚠️ LocationService: DB update failed: $e');
        // Fallback: direct update
        try {
          await SupabaseService.client.from('drivers_profile').update({
            'current_lat': pos.latitude,
            'current_lng': pos.longitude,
          }).eq('id', driverId);
        } catch (_) {}
      }
    });
  }

  void stopTripTracking() {
    if (_tripTrackingSub != null) {
      debugPrint('📍 LocationService: Stopping global trip tracking');
      _tripTrackingSub?.cancel();
      _tripTrackingSub = null;
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _broadcastChannel?.unsubscribe();
      _broadcastChannel = null;
      _activeTripDriverId = null;
      _lastLat = null;
      _lastLng = null;
      _lastHeading = null;
    }
  }

  String _encodeGeohash(double lat, double lng, {int precision = 9}) {
    const base32 = '0123456789bcdefghjkmnpqrstuvwxyz';
    int i = 0;
    bool isEven = true;
    double latMin = -90.0, latMax = 90.0;
    double lngMin = -180.0, lngMax = 180.0;
    double bit = 0.0;
    int ch = 0;
    String hash = '';

    while (hash.length < precision) {
      if (isEven) {
        bit = (lngMin + lngMax) / 2;
        if (lng > bit) {
          ch |= (1 << (4 - i));
          lngMin = bit;
        } else {
          lngMax = bit;
        }
      } else {
        bit = (latMin + latMax) / 2;
        if (lat > bit) {
          ch |= (1 << (4 - i));
          latMin = bit;
        } else {
          latMax = bit;
        }
      }
      isEven = !isEven;
      if (i < 4) {
        i++;
      } else {
        hash += base32[ch];
        i = 0;
        ch = 0;
      }
    }
    return hash;
  }
}
