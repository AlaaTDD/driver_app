
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/geohash_helper.dart';
import 'supabase_service.dart';

class CellSubscriptionService {
  CellSubscriptionService._();
  static final CellSubscriptionService instance = CellSubscriptionService._();

  final List<RealtimeChannel> _activeChannels = [];
  String? _currentCenterCell;
  List<String> _subscribedCells = [];
  List<String> _subscribedCells5 = []; // precision-5 prefixes for DB filter
  Timer? _boundaryDebounceTimer;
  final _driverUpdatesController =
      StreamController<Map<String, DriverLocation>>.broadcast();

  final Map<String, DriverLocation> _driversMap = {};

  Stream<Map<String, DriverLocation>> get driverUpdates =>
      _driverUpdatesController.stream;

  Map<String, DriverLocation> get currentDrivers =>
      Map.unmodifiable(_driversMap);

  /// Subscribe to cells around the user's position.
  /// First call subscribes immediately; subsequent cell changes are debounced.
  Future<void> subscribeToCells(double lat, double lng) async {
    final centerCell = GeohashHelper.encode(lat, lng, precision: 6);

    // Same cell — skip entirely
    if (centerCell == _currentCenterCell) return;

    // First time? Subscribe immediately without debounce
    if (_currentCenterCell == null) {
      await _performSubscription(lat, lng, centerCell);
      return;
    }

    // Subsequent cell changes — debounce to avoid rapid re-subscriptions
    _boundaryDebounceTimer?.cancel();
    _boundaryDebounceTimer = Timer(const Duration(seconds: 2), () async {
      await _performSubscription(lat, lng, centerCell);
    });
  }

  /// Force refresh: re-fetch drivers from DB and reconnect realtime channel.
  /// Safe to call on app resume.
  Future<void> refresh() async {
    if (_currentCenterCell == null || _subscribedCells.isEmpty) return;
    debugPrint('📍 CellSystem: Forcing refresh and realtime reconnect...');

    // First: quickly fetch fresh data from DB (fast path)
    await _fetchInitialDrivers();

    // Then: reconnect realtime channel in background (slow path)
    _unsubscribeRealtime();
    _subscribeToRealtimeChanges();
  }

  Future<void> _performSubscription(
      double lat, double lng, String centerCell) async {
    await _unsubscribeAll();

    _currentCenterCell = centerCell;
    _subscribedCells = [
      centerCell,
      ...GeohashHelper.getNeighborCells(centerCell)
    ];

    // Build precision-5 prefixes used for DB index idx_drivers_profile_geohash5
    _subscribedCells5 = _subscribedCells
        .map((c) => c.length >= 5 ? c.substring(0, 5) : c)
        .toSet()
        .toList();

    debugPrint(
        '📍 CellSystem: Subscribing to ${_subscribedCells.length} cells around $centerCell');

    await _fetchInitialDrivers();
    _subscribeToRealtimeChanges();
    _startStaleCleanup();
  }

  /// Fetch drivers from DB and REPLACE the local map completely.
  /// FIX: was doing merge which caused offline drivers to persist.
  Future<void> _fetchInitialDrivers() async {
    try {
      // FIX: Use geohash5 column (precision=5) that matches our cell prefixes.
      // The old code used 'geohash' (precision=9) vs cells (precision=6) → never matched!
      final data = await SupabaseService.client
          .from('drivers_profile')
          .select(
              'id, current_lat, current_lng, is_available, vehicle_type, geohash5, updated_at')
          .eq('is_available', true)
          .not('current_lat', 'is', null)
          .not('current_lng', 'is', null)
          .inFilter('geohash5', _subscribedCells5);

      final newDrivers = <String, DriverLocation>{};
      final now = DateTime.now().toUtc();
      final currentUserId = SupabaseService.currentUser?.id;

      for (final row in data) {
        final driverId = row['id'] as String;
        if (driverId == currentUserId) continue;

        // Skip stale drivers (no update in last 5 minutes = likely crashed/offline)
        final updatedAtStr = row['updated_at'] as String?;
        DateTime lastUpdated = now;
        if (updatedAtStr != null) {
          try {
            lastUpdated = DateTime.parse(updatedAtStr).toUtc();
          } catch (_) {}
        }

        if (now.difference(lastUpdated).inMinutes > 2) continue; // 2 min stale threshold

        final driverLat = (row['current_lat'] as num).toDouble();
        final driverLng = (row['current_lng'] as num).toDouble();

        newDrivers[driverId] = DriverLocation(
          driverId: driverId,
          lat: driverLat,
          lng: driverLng,
          vehicleType: row['vehicle_type'] as String? ?? 'car',
          lastUpdatedAt: lastUpdated,
        );
      }

      // FIX: Full replace instead of merge.
      // Old code only added new drivers but never removed offline ones.
      _driversMap.clear();
      _driversMap.addAll(newDrivers);

      debugPrint(
          '📍 CellSystem: Fetched ${_driversMap.length} nearby available drivers');
      if (!_driverUpdatesController.isClosed) {
        _driverUpdatesController.add(Map.from(_driversMap));
      }
    } catch (e) {
      debugPrint('❌ CellSystem: Failed to fetch initial drivers: $e');
    }
  }

  void _subscribeToRealtimeChanges() {
    // Use a unique channel name to avoid conflicts after reconnection
    final channelName =
        'nearby-drivers-rt-${DateTime.now().millisecondsSinceEpoch}';
    final channel = SupabaseService.client.channel(channelName);

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers_profile',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.inFilter,
            column: 'geohash5',
            value: _subscribedCells5,
          ),
          callback: (payload) {
            _handleDriverChange(payload);
          },
        )
        .subscribe((status, [error]) {
      debugPrint('📍 CellSystem: Realtime channel status: $status');
      if (error != null) {
        debugPrint('❌ CellSystem: Realtime error: $error');
      }
    });

    _activeChannels.add(channel);
  }

  void _handleDriverChange(PostgresChangePayload payload) {
    final newRecord = payload.newRecord;

    // ── DELETE event ──────────────────────────────────────────────────────
    if (newRecord.isEmpty) {
      final oldRecord = payload.oldRecord;
      if (oldRecord.isNotEmpty) {
        final driverId = oldRecord['id'] as String?;
        if (driverId != null && _driversMap.containsKey(driverId)) {
          _driversMap.remove(driverId);
          if (!_driverUpdatesController.isClosed) {
            _driverUpdatesController.add(Map.from(_driversMap));
          }
          debugPrint('📍 CellSystem: Driver $driverId DELETED');
        }
      }
      return;
    }

    final driverId = newRecord['id'] as String?;
    if (driverId == null) return;

    final currentUserId = SupabaseService.currentUser?.id;
    if (driverId == currentUserId) return;

    // ── Check is_available ────────────────────────────────────────────────
    // NOTE: Without REPLICA IDENTITY FULL on drivers_profile, Supabase will
    // NOT send any event when is_available transitions true→false (RLS filter).
    // Run: ALTER TABLE drivers_profile REPLICA IDENTITY FULL;
    // to fix realtime delivery. Until then, periodic refresh is the fallback.
    final hasIsAvailable = newRecord.containsKey('is_available');
    final isAvailable = newRecord['is_available'] as bool?;
    if (hasIsAvailable && isAvailable != true) {
      if (_driversMap.containsKey(driverId)) {
        _driversMap.remove(driverId);
        if (!_driverUpdatesController.isClosed) {
          _driverUpdatesController.add(Map.from(_driversMap));
        }
        debugPrint('📍 CellSystem: Driver $driverId went OFFLINE (is_available=$isAvailable)');
      }
      return;
    }

    // ── Check location ────────────────────────────────────────────────────
    final lat = newRecord['current_lat'];
    final lng = newRecord['current_lng'];

    // FIX: null lat/lng means set_driver_offline cleared the location.
    // Old code kept the driver in _driversMap when lat/lng were null.
    if (lat == null || lng == null) {
      if (_driversMap.containsKey(driverId)) {
        _driversMap.remove(driverId);
        if (!_driverUpdatesController.isClosed) {
          _driverUpdatesController.add(Map.from(_driversMap));
        }
        debugPrint('📍 CellSystem: Driver $driverId removed — null location (went offline)');
      }
      return;
    }

    final driverLat = (lat as num).toDouble();
    final driverLng = (lng as num).toDouble();
    final driverCell =
        GeohashHelper.encode(driverLat, driverLng, precision: 6);

    if (_subscribedCells.contains(driverCell)) {
      final vehicleType = newRecord['vehicle_type'] as String? ??
          (_driversMap[driverId]?.vehicleType ?? 'car');
      _driversMap[driverId] = DriverLocation(
        driverId: driverId,
        lat: driverLat,
        lng: driverLng,
        vehicleType: vehicleType,
        lastUpdatedAt: DateTime.now().toUtc(),
      );
      debugPrint(
          '📍 CellSystem: Driver $driverId at ($driverLat, $driverLng) cell=$driverCell');
    } else {
      // Driver moved out of our cells
      if (_driversMap.containsKey(driverId)) {
        _driversMap.remove(driverId);
        debugPrint(
            '📍 CellSystem: Driver $driverId moved OUT of range ($driverCell)');
      }
    }

    if (!_driverUpdatesController.isClosed) {
      _driverUpdatesController.add(Map.from(_driversMap));
    }
  }

  /// Unsubscribe only realtime channels (keeps timers)
  void _unsubscribeRealtime() {
    for (final channel in _activeChannels) {
      try {
        SupabaseService.client.removeChannel(channel);
      } catch (e) {
        debugPrint('CellSubscriptionService: removeChannel error — $e');
      }
    }
    _activeChannels.clear();
  }

  /// Unsubscribe everything (channels + timers)
  Future<void> _unsubscribeAll() async {
    _staleCleanupTimer?.cancel();
    _staleCleanupTimer = null;
    _unsubscribeRealtime();
    _driversMap.clear();
    if (!_driverUpdatesController.isClosed) {
      _driverUpdatesController.add({});
    }
  }

  Timer? _staleCleanupTimer;

  /// Stale cleanup every 15 seconds — removes drivers not updated in 2 minutes.
  void _startStaleCleanup() {
    _staleCleanupTimer?.cancel();
    _staleCleanupTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      final cutoff = DateTime.now().toUtc().subtract(const Duration(minutes: 2));
      final stale = _driversMap.entries
          .where((e) => e.value.lastUpdatedAt.isBefore(cutoff))
          .map((e) => e.key)
          .toList();
      if (stale.isEmpty) return;
      for (final id in stale) _driversMap.remove(id);
      debugPrint('📍 CellSystem: Removed ${stale.length} stale drivers');
      if (!_driverUpdatesController.isClosed) {
        _driverUpdatesController.add(Map.from(_driversMap));
      }
    });
  }

  Future<void> dispose() async {
    _staleCleanupTimer?.cancel();
    _staleCleanupTimer = null;
    _boundaryDebounceTimer?.cancel();
    await _unsubscribeAll();
    _driversMap.clear();
    _currentCenterCell = null;
    _subscribedCells = [];
    _subscribedCells5 = [];
    if (!_driverUpdatesController.isClosed) {
      _driverUpdatesController.add({});
    }
  }
}

class DriverLocation {
  final String driverId;
  final double lat;
  final double lng;
  final String vehicleType;
  final DateTime lastUpdatedAt;

  const DriverLocation({
    required this.driverId,
    required this.lat,
    required this.lng,
    required this.vehicleType,
    required this.lastUpdatedAt,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DriverLocation &&
          other.driverId == driverId &&
          other.lat == lat &&
          other.lng == lng;

  @override
  int get hashCode => Object.hash(driverId, lat, lng);
}
