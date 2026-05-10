
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/geohash_helper.dart';
import 'supabase_service.dart';

class CellSubscriptionService {
  CellSubscriptionService._();
  static final CellSubscriptionService instance = CellSubscriptionService._();

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

  Future<void> refresh() async {
    if (_currentCenterCell == null || _subscribedCells.isEmpty) return;
    debugPrint('📍 CellSystem: Forcing refresh and realtime reconnect...');

    // First: quickly fetch fresh data from DB (fast path)
    await _fetchInitialDrivers();

    // Then: restart polling timer
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

  Future<void> _fetchInitialDrivers() async {
    try {
      final data = await SupabaseService.client.rpc(
        'get_nearby_drivers_secure',
        params: {'p_geohash5': _subscribedCells5},
      );

      final newDrivers = <String, DriverLocation>{};
      final now = DateTime.now().toUtc();
      final currentUserId = SupabaseService.currentUser?.id;

      for (final row in data) {
        final driverId = row['id'] as String;
        if (driverId == currentUserId) continue;

        final updatedAtStr = row['updated_at'] as String?;
        DateTime lastUpdated = now;
        if (updatedAtStr != null) {
          try {
            lastUpdated = DateTime.parse(updatedAtStr).toUtc();
          } catch (_) {}
        }

        if (now.difference(lastUpdated).inMinutes > 2) continue;

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

      _driversMap.clear();
      _driversMap.addAll(newDrivers);

      if (!_driverUpdatesController.isClosed) {
        _driverUpdatesController.add(Map.from(_driversMap));
      }
    } catch (e) {
      debugPrint('❌ CellSystem: Failed to fetch drivers: $e');
    }
  }

  Timer? _pollingTimer;

  void _subscribeToRealtimeChanges() {
    // Instead of subscribing to Realtime which requires permissive RLS (and exposes national_id),
    // we poll the secure RPC every 5 seconds. This is more secure and reliable.
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _fetchInitialDrivers();
    });
  }

  /// Unsubscribe everything (channels + timers)
  Future<void> _unsubscribeAll() async {
    _staleCleanupTimer?.cancel();
    _staleCleanupTimer = null;
    _pollingTimer?.cancel();
    _pollingTimer = null;
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
