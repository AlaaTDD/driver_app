
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
  Timer? _boundaryDebounceTimer;
  final _driverUpdatesController =
      StreamController<Map<String, DriverLocation>>.broadcast();

  
  final Map<String, DriverLocation> _driversMap = {};

  
  Stream<Map<String, DriverLocation>> get driverUpdates =>
      _driverUpdatesController.stream;

  
  Map<String, DriverLocation> get currentDrivers =>
      Map.unmodifiable(_driversMap);

  
  
  Future<void> subscribeToCells(double lat, double lng) async {
    final centerCell = GeohashHelper.encode(lat, lng, precision: 6);

    
    if (centerCell == _currentCenterCell) return;

    
    _boundaryDebounceTimer?.cancel();
    _boundaryDebounceTimer = Timer(const Duration(seconds: 2), () async {
      await _performSubscription(lat, lng, centerCell);
    });
  }

  Future<void> _performSubscription(double lat, double lng, String centerCell) async {
    
    await _unsubscribeAll();

    _currentCenterCell = centerCell;
    _subscribedCells = [centerCell, ...GeohashHelper.getNeighborCells(centerCell)];

    debugPrint('📍 CellSystem: Subscribing to ${_subscribedCells.length} cells around $centerCell');

    
    await _fetchInitialDrivers();

    
    _subscribeToRealtimeChanges();

    
    _startPeriodicRefresh();
  }

  
  Future<void> _fetchInitialDrivers() async {
    try {
      
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

    
    final currentUserId = SupabaseService.currentUser?.id;
    if (driverId == currentUserId) return;

    
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
      
      if (_driversMap.containsKey(driverId)) {
        _driversMap.remove(driverId);
        debugPrint(
            '📍 CellSystem: Driver $driverId moved OUT of range ($driverCell)');
      }
    }

    _driverUpdatesController.add(Map.from(_driversMap));
  }

  
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
