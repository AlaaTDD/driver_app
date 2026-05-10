
import 'dart:async';
import 'package:flutter/widgets.dart';
import 'supabase_service.dart';
import '../core/utils/retry_helper.dart';












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

  
  bool get isBroadcasting => _isBroadcasting;

  
  
  Future<void> startBroadcasting({double? lat, double? lng}) async {
    _lastLat = lat ?? _lastLat;
    _lastLng = lng ?? _lastLng;
    _isBroadcasting = true;

    if (_lastLat != null && _lastLng != null) {
      await _upsertPresence(_lastLat!, _lastLng!);
    }

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) {
        if (!_isBroadcasting) return;
        if (_lastLat != null && _lastLng != null) {
          _upsertPresence(_lastLat!, _lastLng!);
        }
      },
    );

    debugPrint('📡 UserPresence: Started broadcasting loop');
  }

  Future<void> updateLocation(double lat, double lng) async {
    _lastLat = lat;
    _lastLng = lng;

    if (!_isBroadcasting) return;

    
    _upsertPresence(lat, lng);
  }

  
  
  Future<void> stopBroadcasting() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _isBroadcasting = false;
    _isPausedByLifecycle = false;

    await _deletePresence();
  }

  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isBroadcasting && !_isPausedByLifecycle) return;

    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      
      
      debugPrint('📡 UserPresence: App backgrounded/killed, pausing broadcast');
      _heartbeatTimer?.cancel();
      _isPausedByLifecycle = true;
      _deletePresence();
    } else if (state == AppLifecycleState.resumed) {
      if (_isPausedByLifecycle) {
        debugPrint('📡 UserPresence: App resumed, restarting broadcast');
        _isPausedByLifecycle = false;
        startBroadcasting(lat: _lastLat, lng: _lastLng);
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

  
  Future<void> _upsertPresence(double lat, double lng) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

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
        },
        maxAttempts: 3,
        onRetry: (e, attempt) => debugPrint('📡 UserPresence: Upsert failed, retrying ($attempt/3)...'),
      );
      // NOTE: drivers_profile location is updated ONLY via DriverHomeRepository.pushLocation()
      // which is called only when is_available = true. Do NOT update it here to avoid
      // triggering realtime events on an offline driver's record.
    } catch (e) {
      debugPrint('❌ UserPresence: Failed to upsert presence after retries: $e');
    }
  }
}
