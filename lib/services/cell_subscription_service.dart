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
  RealtimeChannel? _driversChannel;
  int _channelGeneration = 0;
  bool _isRealtimeSubscribed = false;
  final _driverUpdatesController =
      StreamController<Map<String, DriverLocation>>.broadcast();

  final Map<String, DriverLocation> _driversMap = {};

  Stream<Map<String, DriverLocation>> get driverUpdates =>
      _driverUpdatesController.stream;

  Map<String, DriverLocation> get currentDrivers =>
      Map.unmodifiable(_driversMap);

  /// Subscribe to cells around the user's position.
  /// The initial RPC is a one-shot snapshot; subsequent changes arrive through
  /// Supabase Realtime and update [_driversMap] in place.
  Future<void> subscribeToCells(double lat, double lng) async {
    final centerCell = GeohashHelper.encode(lat, lng, precision: 6);

    if (centerCell == _currentCenterCell) {
      final wasDisconnected = _driversChannel == null;
      _ensureRealtimeSubscription();
      if (wasDisconnected) {
        await _fetchInitialDrivers();
      }
      _emitDrivers();
      return;
    }

    await _performSubscription(centerCell);
  }

  Future<void> refresh() async {
    if (_currentCenterCell == null || _subscribedCells.isEmpty) return;
    debugPrint('📍 CellSystem: Refreshing driver snapshot...');

    _ensureRealtimeSubscription();
    await _fetchInitialDrivers();
  }

  Future<void> _performSubscription(String centerCell) async {
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

    _ensureRealtimeSubscription();
    await _fetchInitialDrivers();
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
          } catch (e, st) {
            debugPrint(
              '⚠️ CellSubscriptionService: invalid driver updated_at "$updatedAtStr": $e\n$st',
            );
          }
        }

        final driverLat = (row['current_lat'] as num?)?.toDouble();
        final driverLng = (row['current_lng'] as num?)?.toDouble();
        if (driverLat == null || driverLng == null) continue;

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

      _emitDrivers();
    } catch (e) {
      debugPrint('❌ CellSystem: Failed to fetch drivers: $e');
    }
  }

  void _ensureRealtimeSubscription() {
    if (_driversChannel != null) return;
    _subscribeToRealtimeChanges();
  }

  void _subscribeToRealtimeChanges() {
    final generation = ++_channelGeneration;
    final channel =
        SupabaseService.client.channel('nearby-drivers-profile-live');

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'drivers_profile',
      callback: (payload) {
        if (generation != _channelGeneration) return;
        _handleDriverPayload(payload);
      },
    );

    _driversChannel = channel;
    channel.subscribe((status, [error]) {
      _handleRealtimeStatus(generation, status, error);
    });
  }

  void _handleRealtimeStatus(
    int generation,
    RealtimeSubscribeStatus status,
    Object? error,
  ) {
    if (generation != _channelGeneration) return;

    if (status == RealtimeSubscribeStatus.subscribed) {
      if (!_isRealtimeSubscribed) {
        debugPrint('📍 CellSystem: Realtime subscribed');
      }
      _isRealtimeSubscribed = true;
      return;
    }

    if (status == RealtimeSubscribeStatus.closed) {
      _isRealtimeSubscribed = false;
      _driversChannel = null;
      debugPrint('📍 CellSystem: Realtime closed');
      return;
    }

    final errorText = error?.toString() ?? '';
    final isAutoReconnectNoise =
        status == RealtimeSubscribeStatus.channelError &&
            (error == null || errorText.contains('code: 1006'));
    if (isAutoReconnectNoise) return;

    _dropRealtimeChannel();
    debugPrint('📍 CellSystem: Realtime status=$status error=$error');
  }

  void _dropRealtimeChannel() {
    final channel = _driversChannel;
    _driversChannel = null;
    _isRealtimeSubscribed = false;
    if (channel != null) {
      unawaited(SupabaseService.client.removeChannel(channel));
    }
  }

  /// Unsubscribe realtime channels.
  /// Intentionally keeps _driversMap intact so old car markers stay visible
  /// on the map until _fetchInitialDrivers() atomically replaces them.
  /// This prevents the flash where all cars disappear on cell resubscription.
  Future<void> _unsubscribeAll() async {
    _channelGeneration++;
    final channel = _driversChannel;
    _driversChannel = null;
    _isRealtimeSubscribed = false;
    if (channel != null) {
      await SupabaseService.client.removeChannel(channel);
    }
    // Do NOT clear _driversMap here — old data stays visible until replaced.
    // Atomic replacement happens inside _fetchInitialDrivers().
  }

  void _handleDriverPayload(PostgresChangePayload payload) {
    final row = payload.eventType == PostgresChangeEvent.delete
        ? payload.oldRecord
        : payload.newRecord;
    final driverId = row['id'] as String?;
    if (driverId == null) return;

    if (payload.eventType == PostgresChangeEvent.delete) {
      _removeDriver(driverId);
      return;
    }

    final location = _parseVisibleDriver(payload.newRecord);
    if (location == null) {
      _removeDriver(driverId);
      return;
    }

    _driversMap[driverId] = location;
    _emitDrivers();
  }

  DriverLocation? _parseVisibleDriver(Map<String, dynamic> row) {
    final driverId = row['id'] as String?;
    if (driverId == null || driverId == SupabaseService.currentUser?.id) {
      return null;
    }

    if (row['is_available'] != true || row['is_verified'] != true) {
      return null;
    }

    final lat = (row['current_lat'] as num?)?.toDouble();
    final lng = (row['current_lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    final geohash5 = row['geohash5'] as String? ??
        GeohashHelper.encode(lat, lng, precision: 5);
    if (!_subscribedCells5.contains(geohash5)) return null;

    return DriverLocation(
      driverId: driverId,
      lat: lat,
      lng: lng,
      vehicleType: row['vehicle_type'] as String? ?? 'car',
      lastUpdatedAt:
          _parseUpdatedAt(row['updated_at']) ?? DateTime.now().toUtc(),
    );
  }

  DateTime? _parseUpdatedAt(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toUtc();
  }

  void _removeDriver(String driverId) {
    if (_driversMap.remove(driverId) != null) {
      _emitDrivers();
    }
  }

  void _emitDrivers() {
    if (!_driverUpdatesController.isClosed) {
      _driverUpdatesController.add(Map.from(_driversMap));
    }
  }

  Future<void> dispose() async {
    await _unsubscribeAll();
    // Full reset on sign-out — _unsubscribeAll() no longer clears the map,
    // so we do it explicitly here to ensure no stale data survives logout.
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
