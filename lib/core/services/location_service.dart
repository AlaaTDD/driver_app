// /host/Volumes/alaaMac/driverr/taxi/taxi_app/lib/services/location_service.dart
//
// ✅ FIX (Map Module):
//   1. Throttle على كتابة DB: 3s زمني + 15m مكاني بين كل كتابتين
//   2. distanceFilter رُفع من 2m → 5m لتقليل أحداث GPS الصغيرة
//   3. Broadcast لا يزال فوري (رخيص — لا throttle)
//   4. cleanup كامل للـ throttle state في stopTripTracking()
//   5. استخدام النسخة الموحدة من upsert_driver_location

import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';
import '../errors/exceptions.dart';
import '../utils/geohash_helper.dart';
import 'package:snapix/core/utils/app_logger.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  static LocationService get instance => _instance;
  LocationService._internal();

  final GeolocatorPlatform _geolocator = GeolocatorPlatform.instance;
  StreamSubscription<Position>? _tripTrackingSub;
  String? _activeTripDriverId;
  RealtimeChannel? _broadcastChannel;
  double? _lastLat;
  double? _lastLng;
  double? _lastHeading;

  // ─── Throttle لكتابة DB ───────────────────────────────────────
  /// أقل فترة زمنية بين كتابتين متتاليتين للـ DB
  static const Duration _minDbWriteInterval = Duration(seconds: 3);

  /// أقل مسافة (متر) تضمن الكتابة بغض النظر عن الزمن
  static const double _minDbWriteMeters = 15.0;

  DateTime? _lastDbWriteTime;
  double? _lastDbWrittenLat;
  double? _lastDbWrittenLng;
  // ─────────────────────────────────────────────────────────────

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

      AppLogger.debug(
          '⚠️ LocationService: GPS disabled and no last known location. Throwing error.');
      throw ValidationException('location_disabled');
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
        AppLogger.error('LocationService: All 3 fallbacks failed. Last error: $e');
        rethrow;
      }
    }
  }

  StreamController<Position>? _locationController;
  StreamSubscription<Position>? _geolocatorSub;

  Stream<Position> getLocationStream() {
    if (_locationController == null || _locationController!.isClosed) {
      // [APP-H-01 FIXED] Cancel any orphaned geolocator subscription before
      // rebuilding. If the controller was closed outside of stopAllTracking()
      // (e.g. via a direct .close() call), _geolocatorSub would keep emitting
      // in the background, draining battery.
      _geolocatorSub?.cancel();
      _geolocatorSub = null;
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
      AppLogger.debug(
          '⚠️ LocationService (Stream): GPS disabled. Waiting for location to be enabled.');
      return;
    }

    yield* _geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        // ✅ FIX: رفعنا من 2m → 5m — يقلل الأحداث الكثيرة عند التحرك البطيء
        distanceFilter: 5,
      ),
    );
  }

  Future<void> startTripTracking(String driverId) async {
    if (_tripTrackingSub != null && _activeTripDriverId == driverId) return;

    // [APP-H-02 FIXED] Overlap-then-teardown pattern: spin up the new channel
    // and subscription BEFORE cancelling old ones.
    // Previously stopTripTracking() ran first, leaving a brief window where
    // position events were silently dropped (_broadcastChannel was null).
    final oldSub     = _tripTrackingSub;
    final oldChannel = _broadcastChannel;

    _activeTripDriverId = driverId;
    _lastDbWriteTime    = null;
    _lastDbWrittenLat   = null;
    _lastDbWrittenLng   = null;

    AppLogger.debug(
        '📍 LocationService: Starting global trip tracking for driver $driverId');

    // ① Spin up new broadcast channel first (no gap)
    _broadcastChannel =
        SupabaseService.client.channel('trip-tracking-$driverId');
    _broadcastChannel!.subscribe((status, [error]) {
      AppLogger.info('LocationService: Broadcast channel status=$status');
      // بمجرد الاشتراك، أرسل آخر موقع معروف فوراً
      if (_lastLat != null) {
        _broadcastChannel?.sendBroadcastMessage(
          event: 'location_update',
          payload: {
            'lat': _lastLat,
            'lng': _lastLng,
            'heading': _lastHeading ?? 0.0,
          },
        );
      }
    });

    // ② Tear down OLD subscription/channel now that new channel is queued.
    //    Any position event between here and _tripTrackingSub assignment below
    //    goes to the new _broadcastChannel (already set above).
    oldSub?.cancel();
    if (oldChannel != null) {
      SupabaseService.client.removeChannel(oldChannel);
    }

    // IMMEDIATELY fetch location لتجنب انتظار stream (distance filter)
    try {
      final pos = await getCurrentLocation();
      if (_lastLat == null) {
        _lastLat = pos.latitude;
        _lastLng = pos.longitude;
        _lastHeading = pos.heading;

        // Broadcast أول موقع — فوري بدون throttle
        await _broadcastChannel?.sendBroadcastMessage(
          event: 'location_update',
          payload: {
            'lat': pos.latitude,
            'lng': pos.longitude,
            'heading': pos.heading,
          },
        );

        // كتابة DB أولى — force=true يتجاوز الـ throttle
        await _writeLocationToDb(
          driverId,
          pos.latitude,
          pos.longitude,
          pos.heading,
          force: true,
        );
      }
    } catch (e) {
      AppLogger.debug(
          '⚠️ LocationService.startTripTracking: Initial GPS fix failed: $e');
    }

    _tripTrackingSub = getLocationStream().listen((pos) async {
      // حفظ آخر موقع معروف دائماً
      _lastLat = pos.latitude;
      _lastLng = pos.longitude;
      _lastHeading = pos.heading;

      // ① Broadcast فوري — لا throttle (websocket، رخيص جداً)
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
        AppLogger.warning('LocationService: broadcast failed: $e');
      }

      // ② كتابة DB — مع throttle زمني + مكاني
      await _writeLocationToDb(
        driverId,
        pos.latitude,
        pos.longitude,
        pos.heading,
      );
    });
  }

  /// يكتب الموقع للـ DB.
  /// [force] = true يتجاوز الـ throttle (كتابة أولى فقط).
  Future<void> _writeLocationToDb(
    String driverId,
    double lat,
    double lng,
    double heading, {
    bool force = false,
  }) async {
    if (!force) {
      final now = DateTime.now();

      // تحقق من الـ time throttle
      if (_lastDbWriteTime != null &&
          now.difference(_lastDbWriteTime!) < _minDbWriteInterval) {
        return; // أقل من 3 ثوان من آخر كتابة — تخطى
      }

      // تحقق من الـ distance throttle
      if (_lastDbWrittenLat != null && _lastDbWrittenLng != null) {
        final movedMeters = _haversineMeters(
          _lastDbWrittenLat!,
          _lastDbWrittenLng!,
          lat,
          lng,
        );
        if (movedMeters < _minDbWriteMeters) {
          return; // تحرك أقل من 15 متر — تخطى
        }
      }
    }

    try {
      final geohash = GeohashHelper.encode(lat, lng); // precision=6
      final geohash5 =
          geohash.length > 5 ? geohash.substring(0, 5) : geohash;

      // ✅ استخدام النسخة الموحدة من upsert_driver_location
      await SupabaseService.client.rpc('upsert_driver_location', params: {
        'p_driver_id': driverId,
        'p_lat': lat,
        'p_lng': lng,
        'p_heading': heading,
        'p_geohash': geohash,
        'p_geohash5': geohash5,
      });

      // حدّث الـ throttle markers بعد الكتابة الناجحة
      _lastDbWriteTime = DateTime.now();
      _lastDbWrittenLat = lat;
      _lastDbWrittenLng = lng;

      AppLogger.debug(
          '✅ LocationService: DB updated [$lat, $lng] gh=$geohash gh5=$geohash5');
    } catch (e) {
      AppLogger.debug(
          '⚠️ LocationService: upsert_driver_location failed: $e — trying fallback');

      // Fallback: direct update على drivers_profile مع geohash
      try {
        final geohash = GeohashHelper.encode(lat, lng);
        final geohash5 =
            geohash.length > 5 ? geohash.substring(0, 5) : geohash;
        await SupabaseService.client.from('drivers_profile').update({
          'current_lat': lat,
          'current_lng': lng,
          'heading': heading,
          'geohash': geohash,
          'geohash5': geohash5,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', driverId);

        _lastDbWriteTime = DateTime.now();
        _lastDbWrittenLat = lat;
        _lastDbWrittenLng = lng;

        AppLogger.debug(
            '✅ LocationService: Fallback direct update OK [$lat, $lng]');
      } catch (e2, st) {
        AppLogger.debug(
            '❌ LocationService: Fallback also failed: $e2\n$st');
      }
    }
  }

  void stopTripTracking() {
    if (_tripTrackingSub != null) {
      AppLogger.info('LocationService: Stopping global trip tracking');
      _tripTrackingSub?.cancel();
      _tripTrackingSub = null;
      if (_broadcastChannel != null) {
        SupabaseService.client.removeChannel(_broadcastChannel!);
      }
      _broadcastChannel = null;
      _lastLat = null;
      _lastLng = null;
      _lastHeading = null;
      // ✅ FIX: تنظيف كامل لـ throttle state
      _lastDbWriteTime = null;
      _lastDbWrittenLat = null;
      _lastDbWrittenLng = null;
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

  /// Haversine distance بالمتر
  static double _haversineMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.pow(math.sin(dLng / 2), 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
