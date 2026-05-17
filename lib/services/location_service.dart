import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../core/utils/geohash_helper.dart';







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
      
      debugPrint('⚠️ LocationService: GPS disabled and no last known location. Throwing error.');
      throw Exception('location_disabled');
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

  

  
  
  
  StreamController<Position>? _locationController;
  StreamSubscription<Position>? _geolocatorSub;

  Stream<Position> getLocationStream() {
    if (_locationController == null || _locationController!.isClosed) {
      _locationController = StreamController<Position>.broadcast(
        onListen: () {
          _geolocatorSub = _createLocationStream().listen(
            (pos) => _locationController?.add(pos),
            onError: (e) => _locationController?.addError(e),
          );
        },
        onCancel: () {
          _geolocatorSub?.cancel();
        },
      );
    }
    return _locationController!.stream;
  }

  Stream<Position> _createLocationStream() async* {
    final isEnabled = await _geolocator.isLocationServiceEnabled();
    if (!isEnabled) {
      debugPrint('⚠️ LocationService (Stream): GPS disabled. Waiting for location to be enabled.');
      return;
    }

    yield* _geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 2,
      ),
    );
  }

  Future<void> startTripTracking(String driverId) async {
    if (_tripTrackingSub != null) {
      if (_activeTripDriverId == driverId) return;
      stopTripTracking();
    }
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
        try {
          _broadcastChannel!.sendBroadcastMessage(
            event: 'location_update',
            payload: {'lat': _lastLat, 'lng': _lastLng, 'heading': _lastHeading ?? 0.0},
          );
        } catch (e, st) {
          debugPrint('⚠️ LocationService heartbeat broadcast failed: $e\n$st');
        }
      }
    });

    // IMMEDIATELY fetch location so we don't wait for the stream (which has distance filter)
    try {
      final pos = await getCurrentLocation();
      if (_lastLat == null) {
        _lastLat = pos.latitude;
        _lastLng = pos.longitude;
        _lastHeading = pos.heading;
        
        await _broadcastChannel?.sendBroadcastMessage(
          event: 'location_update',
          payload: {'lat': pos.latitude, 'lng': pos.longitude, 'heading': pos.heading},
        );
        
        try {
          final geohash = GeohashHelper.encode(pos.latitude, pos.longitude);
          final geohash5 = geohash.length > 5 ? geohash.substring(0, 5) : geohash;
          await SupabaseService.client.from('drivers_profile').update({
            'current_lat': pos.latitude,
            'current_lng': pos.longitude,
            'geohash': geohash,
            'geohash5': geohash5,
          }).eq('id', driverId);
        } catch (e, st) {
          debugPrint('⚠️ LocationService initial geohash DB update failed: $e\n$st');
        }
      }
    } catch (e) {
      debugPrint('⚠️ LocationService.startTripTracking: Initial GPS fix failed: $e');
    }
    
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
        final geohash = GeohashHelper.encode(pos.latitude, pos.longitude);
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
          final geohash = GeohashHelper.encode(pos.latitude, pos.longitude);
          final geohash5 = geohash.length > 5 ? geohash.substring(0, 5) : geohash;
          await SupabaseService.client.from('drivers_profile').update({
            'current_lat': pos.latitude,
            'current_lng': pos.longitude,
            'geohash': geohash,
            'geohash5': geohash5,
          }).eq('id', driverId);
        } catch (e, st) {
          debugPrint('⚠️ LocationService fallback driver location update failed: $e\n$st');
        }
      }
    });
  }

  void stopTripTracking() {
    if (_tripTrackingSub != null) {
      debugPrint('📍 LocationService: Stopping global trip tracking');
      _tripTrackingSub?.cancel();
      _tripTrackingSub = null;
      _heartbeatTimer?.cancel();
      if (_broadcastChannel != null) {
        SupabaseService.client.removeChannel(_broadcastChannel!);
      }
      _broadcastChannel = null;
      _lastLat = null;
      _lastLng = null;
    }
  }

  void stopAllTracking() {
    stopTripTracking();
    _geolocatorSub?.cancel();
    _geolocatorSub = null;
    if (_locationController != null && !_locationController!.isClosed) {
      _locationController?.close();
    }
    _locationController = null;
  }

}
