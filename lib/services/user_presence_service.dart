// lib/services/user_presence_service.dart
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'supabase_service.dart';
import '../core/utils/retry_helper.dart';

/// Broadcasts the current user's presence (lat/lng) to the `user_presence`
/// table so that drivers can see where active users are on the heatmap.
///
/// **Lifecycle:**
///   1. User opens home screen → `startBroadcasting(lat, lng)`
///   2. Heartbeat upserts every 30s so drivers know user is still alive
///   3. When user location changes → `updateLocation(lat, lng)`
///   4. User leaves / app closes → `stopBroadcasting()` → deletes the row
///
/// FIX P3-04: SQL schema removed from inline comment to avoid staleness.
/// See migration file for current schema: `supabase/migrations/20260429_add_user_presence_table.sql`
class UserPresenceService with WidgetsBindingObserver {
  UserPresenceService._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final UserPresenceService instance = UserPresenceService._();

  Timer? _heartbeatTimer;
  double? _lastLat;
  double? _lastLng;
  bool _isBroadcasting = false;
  bool _isPausedByLifecycle = false;

  /// Whether this user is currently broadcasting presence
  bool get isBroadcasting => _isBroadcasting;

  /// Start broadcasting presence. Call when user opens the home screen.
  /// Immediately upserts a row, then keeps it alive with a heartbeat.
  Future<void> startBroadcasting(double lat, double lng) async {
    _lastLat = lat;
    _lastLng = lng;
    _isBroadcasting = true;

    // Upsert immediately
    await _upsertPresence(lat, lng);

    // Heartbeat every 30 seconds to keep the row fresh
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        // FIX RC04: Guard against null after stopBroadcasting race
        if (_lastLat == null || _lastLng == null || !_isBroadcasting) return;
        _upsertPresence(_lastLat!, _lastLng!);
      },
    );

    debugPrint('📡 UserPresence: Started broadcasting at ($lat, $lng)');
  }

  /// Update the broadcasted location (called when user moves).
  Future<void> updateLocation(double lat, double lng) async {
    _lastLat = lat;
    _lastLng = lng;

    if (!_isBroadcasting) return;

    // Don't wait — fire-and-forget for performance
    _upsertPresence(lat, lng);
  }

  /// Stop broadcasting. Call when user leaves home screen or app closes.
  /// Deletes the presence row so the driver's heatmap removes the user.
  Future<void> stopBroadcasting() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isBroadcasting = false;
    _isPausedByLifecycle = false;

    await _deletePresence();
  }

  /// App Lifecycle handling to prevent ghost users when app is killed or backgrounded
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isBroadcasting && !_isPausedByLifecycle) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // App went to background or was killed from RAM
      // Stop heartbeat and delete presence immediately
      debugPrint('📡 UserPresence: App backgrounded/killed, pausing broadcast');
      _heartbeatTimer?.cancel();
      _isPausedByLifecycle = true;
      _deletePresence();
    } else if (state == AppLifecycleState.resumed) {
      // App came back to foreground
      if (_isPausedByLifecycle && _lastLat != null && _lastLng != null) {
        debugPrint('📡 UserPresence: App resumed, restarting broadcast');
        _isPausedByLifecycle = false;
        startBroadcasting(_lastLat!, _lastLng!);
      }
    }
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

  /// Upsert the user's presence row
  Future<void> _upsertPresence(double lat, double lng) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    try {
      await withRetry(
        () => SupabaseService.client.from('user_presence').upsert({
          'user_id': user.id,
          'lat': lat,
          'lng': lng,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id'),
        maxAttempts: 3,
        onRetry: (e, attempt) => debugPrint('📡 UserPresence: Upsert failed, retrying ($attempt/3)...'),
      );
    } catch (e) {
      debugPrint('❌ UserPresence: Failed to upsert presence after retries: $e');
    }
  }
}
