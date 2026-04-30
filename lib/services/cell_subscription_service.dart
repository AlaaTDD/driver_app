// lib/services/cell_subscription_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/utils/geohash_helper.dart';
import 'supabase_service.dart';

/// Manages realtime subscriptions to geohash cells for nearby driver tracking.
///
/// HOW IT WORKS:
/// 1. User opens home screen → subscribeToCells(userLat, userLng)
/// 2. This fetches all available drivers whose geohash is in the user's
///    current cell + 8 neighbors (9 cells total, ~1.2km each)
/// 3. It then subscribes to Supabase Realtime on the `drivers_profile` table
/// 4. When a driver updates their row (goes online, moves, goes offline),
///    we process the change and update our map
/// 5. The stream emits the full driver map to the UI
class CellSubscriptionService {
  CellSubscriptionService._();
  static final CellSubscriptionService instance = CellSubscriptionService._();

  final List<RealtimeChannel> _activeChannels = [];
  String? _currentCenterCell;
  List<String> _subscribedCells = [];
  Timer? _boundaryDebounceTimer;
  final _driverUpdatesController =
      StreamController<Map<String, DriverLocation>>.broadcast();

  /// Map of active drivers keyed by driver_id
  final Map<String, DriverLocation> _driversMap = {};

  /// Stream of all currently visible drivers in the subscribed cells
  Stream<Map<String, DriverLocation>> get driverUpdates =>
      _driverUpdatesController.stream;

  /// Returns the current set of drivers (snapshot)
  Map<String, DriverLocation> get currentDrivers =>
      Map.unmodifiable(_driversMap);

  /// Subscribe to cells around the given position.
  /// If the center cell hasn't changed, this is a no-op.
  Future<void> subscribeToCells(double lat, double lng) async {
    final centerCell = GeohashHelper.encode(lat, lng, precision: 6);

    // Don't re-subscribe if still in the same center cell
    if (centerCell == _currentCenterCell) return;

    // FIX H13: Debounce rapid boundary crossing to prevent Supabase connection exhaustion
    _boundaryDebounceTimer?.cancel();
    _boundaryDebounceTimer = Timer(const Duration(seconds: 2), () async {
      await _performSubscription(lat, lng, centerCell);
    });
  }

  Future<void> _performSubscription(double lat, double lng, String centerCell) async {
    // Clean up old subscriptions
    await _unsubscribeAll();

    _currentCenterCell = centerCell;
    _subscribedCells = [centerCell, ...GeohashHelper.getNeighborCells(centerCell)];

    debugPrint('📍 CellSystem: Subscribing to ${_subscribedCells.length} cells around $centerCell');

    // ─── Step 1: Fetch all available drivers in these cells ──────────
    await _fetchInitialDrivers();

    // ─── Step 2: Subscribe to realtime changes on drivers_profile ────
    _subscribeToRealtimeChanges();

    // FIX C07: Start periodic refresh to prune stale ghost drivers
    _startPeriodicRefresh();
  }

  /// Fetch current online drivers from the database
  Future<void> _fetchInitialDrivers() async {
    try {
      // FIX PB02: Filter by geohash at DB level — not full table scan
      final data = await SupabaseService.client
          .from('drivers_profile')
          .select('id, current_lat, current_lng, is_available, vehicle_type, geohash')
          .eq('is_available', true)
          .not('current_lat', 'is', null)
          .not('current_lng', 'is', null)
          .inFilter('geohash', _subscribedCells);

      _driversMap.clear();

      for (final row in data) {
        final driverLat = (row['current_lat'] as num).toDouble();
        final driverLng = (row['current_lng'] as num).toDouble();
        final driverId = row['id'] as String;

        // Skip our own user if they happen to be a driver too
        final currentUserId = SupabaseService.currentUser?.id;
        if (driverId == currentUserId) continue;

        _driversMap[driverId] = DriverLocation(
          driverId: driverId,
          lat: driverLat,
          lng: driverLng,
          vehicleType: row['vehicle_type'] as String? ?? 'car',
        );
      }

      debugPrint(
          '📍 CellSystem: Found ${_driversMap.length} nearby drivers');
      _driverUpdatesController.add(Map.from(_driversMap));
    } catch (e) {
      debugPrint('❌ CellSystem: Failed to fetch initial drivers: $e');
    }
  }

  /// Subscribe to Supabase Realtime for driver location changes
  void _subscribeToRealtimeChanges() {
    final channel = SupabaseService.client.channel('nearby-drivers-rt');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'drivers_profile',
          callback: (payload) {
            _handleDriverChange(payload);
          },
        )
        .subscribe((status, [error]) {
      debugPrint('📍 CellSystem: Realtime channel status: $status');
    });

    _activeChannels.add(channel);
  }

  void _handleDriverChange(PostgresChangePayload payload) {
    final newRecord = payload.newRecord;

    // DELETE event
    if (newRecord.isEmpty) {
      final oldRecord = payload.oldRecord;
      if (oldRecord.isNotEmpty) {
        final driverId = oldRecord['id'] as String?;
        if (driverId != null && _driversMap.containsKey(driverId)) {
          _driversMap.remove(driverId);
          _driverUpdatesController.add(Map.from(_driversMap));
          debugPrint('📍 CellSystem: Driver $driverId deleted');
        }
      }
      return;
    }

    final driverId = newRecord['id'] as String?;
    final isAvailable = newRecord['is_available'] as bool? ?? false;
    final lat = newRecord['current_lat'];
    final lng = newRecord['current_lng'];

    if (driverId == null) return;

    // Skip our own user if they happen to be a driver too
    final currentUserId = SupabaseService.currentUser?.id;
    if (driverId == currentUserId) return;

    // If driver went offline or has no location → remove
    if (!isAvailable || lat == null || lng == null) {
      if (_driversMap.containsKey(driverId)) {
        _driversMap.remove(driverId);
        _driverUpdatesController.add(Map.from(_driversMap));
        debugPrint('📍 CellSystem: Driver $driverId went OFFLINE');
      }
      return;
    }

    final driverLat = (lat as num).toDouble();
    final driverLng = (lng as num).toDouble();
    final driverCell =
        GeohashHelper.encode(driverLat, driverLng, precision: 6);

    if (_subscribedCells.contains(driverCell)) {
      // Driver is in our range — add/update
      final vehicleType =
          newRecord['vehicle_type'] as String? ?? 'car';
      _driversMap[driverId] = DriverLocation(
        driverId: driverId,
        lat: driverLat,
        lng: driverLng,
        vehicleType: vehicleType,
      );
      debugPrint(
          '📍 CellSystem: Driver $driverId at ($driverLat, $driverLng) cell=$driverCell');
    } else {
      // Driver moved out of our range — remove
      if (_driversMap.containsKey(driverId)) {
        _driversMap.remove(driverId);
        debugPrint(
            '📍 CellSystem: Driver $driverId moved OUT of range ($driverCell)');
      }
    }

    _driverUpdatesController.add(Map.from(_driversMap));
  }

  /// Clean up all subscriptions
  Future<void> _unsubscribeAll() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    for (final channel in _activeChannels) {
      try {
        await SupabaseService.client.removeChannel(channel);
      } catch (e) {
        debugPrint('CellSubscriptionService: removeChannel error — $e');
      }
    }
    _activeChannels.clear();
  }

  // FIX C07: Periodic refresh to prune stale drivers
  Timer? _refreshTimer;

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_subscribedCells.isNotEmpty) {
        debugPrint('📍 CellSystem: Periodic driver refresh...');
        _fetchInitialDrivers();
      }
    });
  }

  /// Dispose completely (e.g., on logout)
  Future<void> dispose() async {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _boundaryDebounceTimer?.cancel();
    await _unsubscribeAll();
    _driversMap.clear();
    _currentCenterCell = null;
    _subscribedCells = [];
    if (!_driverUpdatesController.isClosed) {
      await _driverUpdatesController.close();
    }
  }
}

/// Lightweight model for a driver's live location
class DriverLocation {
  final String driverId;
  final double lat;
  final double lng;
  final String vehicleType;

  const DriverLocation({
    required this.driverId,
    required this.lat,
    required this.lng,
    required this.vehicleType,
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
