import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'supabase_service.dart';
import '../core/utils/retry_helper.dart';

class UserPresenceService with WidgetsBindingObserver {
  UserPresenceService._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final UserPresenceService instance = UserPresenceService._();

  double? _lastLat;
  double? _lastLng;
  double? _writtenLat;
  double? _writtenLng;
  bool _isBroadcasting = false;
  bool _pausedByLifecycle = false;

  /// Minimum distance in meters before we write a new presence row.
  /// Prevents redundant DB writes when the user is stationary.
  static const double _minMovementMeters = 20.0;
  DateTime? _lastPresenceWrite;
  static const Duration _minWriteInterval = Duration(seconds: 10);

  bool get isBroadcasting => _isBroadcasting;

  Future<void> startBroadcasting({double? lat, double? lng}) async {
    final resolvedLat = lat ?? _lastLat;
    final resolvedLng = lng ?? _lastLng;
    _isBroadcasting = true;
    _pausedByLifecycle = false;

    if (resolvedLat == null || resolvedLng == null) {
      debugPrint('📡 UserPresence: Waiting for GPS — not writing to DB');
    } else {
      _lastLat = resolvedLat;
      _lastLng = resolvedLng;
      // Always write immediately on start if we have location
      await _upsertPresence(_lastLat!, _lastLng!, force: true);
    }

    debugPrint('📡 UserPresence: Started event-driven broadcasting');
  }

  Future<void> updateLocation(double lat, double lng) async {
    _lastLat = lat;
    _lastLng = lng;

    if (!_isBroadcasting) return;
    if (_pausedByLifecycle) return;

    await _upsertPresence(lat, lng);
  }

  Future<void> stopBroadcasting() async {
    _isBroadcasting = false;
    _pausedByLifecycle = false;
    _writtenLat = null;
    _writtenLng = null;

    await _deletePresence();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isExitState(state)) {
      if (!_isBroadcasting || _pausedByLifecycle) return;
      _pausedByLifecycle = true;
      _writtenLat = null;
      _writtenLng = null;
      debugPrint('📡 UserPresence: App left foreground, deleting presence');
      unawaited(_deletePresence());
      return;
    }

    if (state == AppLifecycleState.resumed && _pausedByLifecycle) {
      _pausedByLifecycle = false;
      if (!_isBroadcasting || _lastLat == null || _lastLng == null) return;
      debugPrint('📡 UserPresence: App resumed, restoring presence');
      unawaited(_upsertPresence(_lastLat!, _lastLng!, force: true));
    }
  }

  bool _isExitState(AppLifecycleState state) {
    return state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden;
  }

  Future<void> _deletePresence() async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      await SupabaseService.client
          .from('user_presence')
          .delete()
          .eq('user_id', userId);

      debugPrint('📡 UserPresence: Presence deleted from DB');
    } catch (e) {
      debugPrint('❌ UserPresence: Failed to delete presence: $e');
    }
  }

  Future<void> _upsertPresence(double lat, double lng,
      {bool force = false}) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    // Skip write if the user hasn't moved significantly.
    if (!force && _writtenLat != null && _writtenLng != null) {
      if (_haversineMeters(_writtenLat!, _writtenLng!, lat, lng) <
          _minMovementMeters) {
        return;
      }
    }

    final now = DateTime.now();
    if (!force &&
        _lastPresenceWrite != null &&
        now.difference(_lastPresenceWrite!) < _minWriteInterval) {
      return;
    }
    _lastPresenceWrite = now;

    try {
      await withRetry(
        () async {
          if (!_isBroadcasting) return;

          await SupabaseService.client.from('user_presence').upsert({
            'user_id': user.id,
            'lat': lat,
            'lng': lng,
            'last_seen': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'user_id');
          _writtenLat = lat;
          _writtenLng = lng;
        },
        maxAttempts: 3,
        onRetry: (e, attempt) => debugPrint(
            '📡 UserPresence: Upsert failed, retrying ($attempt/3)...'),
      );
      // NOTE: drivers_profile location is updated ONLY via DriverHomeRepository.pushLocation()
      // which is called only when is_available = true. Do NOT update it here to avoid
      // triggering realtime events on an offline driver's record.
    } catch (e) {
      debugPrint('❌ UserPresence: Failed to upsert presence after retries: $e');
    }
  }

  /// Approximate Haversine distance in meters between two coordinates.
  static double _haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0; // Earth radius in meters
    final dLat = (lat2 - lat1) * 3.141592653589793 / 180;
    final dLng = (lng2 - lng1) * 3.141592653589793 / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * 3.141592653589793 / 180) *
            math.cos(lat2 * 3.141592653589793 / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return R * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}
