
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

















class HeatmapService with WidgetsBindingObserver {
  HeatmapService._() {
    WidgetsBinding.instance.addObserver(this);
  }
  static final HeatmapService instance = HeatmapService._();

  
  static const double hexRadiusMeters = 300.0;

  
  
  static const Duration _staleDuration = Duration(seconds: 45);

  Timer? _staleCleanupTimer;
  RealtimeChannel? _realtimeChannel;
  bool _isDisposed = false;

  final _heatmapController =
      StreamController<List<HeatmapCell>>.broadcast();

  
  Stream<List<HeatmapCell>> get heatmapUpdates => _heatmapController.stream;

  
  final Map<String, _UserPresenceEntry> _presenceMap = {};

  List<HeatmapCell> _currentCells = [];

  
  List<HeatmapCell> get currentCells => List.unmodifiable(_currentCells);

  

  
  
  
  
  Future<void> startRealtimeUpdates() async {
    _isDisposed = false; // Allow restarting after sign-out
    if (_realtimeChannel != null) return;

    await _fetchAllPresence();
    _subscribeToRealtime();
    _startStaleCleanup();
  }

  
  void stopRealtimeUpdates() {
    _staleCleanupTimer?.cancel();
    _staleCleanupTimer = null;
    _unsubscribeRealtime();
    _presenceMap.clear();
    _currentCells = [];
    if (!_heatmapController.isClosed) {
      _heatmapController.add([]);
    }
  }

  
  void dispose() {
    _isDisposed = true;
    // WidgetsBinding.instance.removeObserver(this); // Singleton stays alive
    stopRealtimeUpdates();
    // Do NOT close _heatmapController because this is a Singleton.
    // If user signs out and signs back in, the stream must still be open.
    if (!_heatmapController.isClosed) {
      _heatmapController.add([]); // Emit empty to clear map
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      
      stopRealtimeUpdates();
    } else if (state == AppLifecycleState.resumed) {
      if (!_isDisposed) {
        startRealtimeUpdates();
      }
    }
  }

  

  
  Future<void> _fetchAllPresence() async {
    try {
      final cutoff = DateTime.now()
          .toUtc()
          .subtract(_staleDuration)
          .toIso8601String();

      final data = await SupabaseService.client
          .from('user_presence')
          .select('user_id, lat, lng, last_seen')
          .gte('last_seen', cutoff);

      _presenceMap.clear();

      
      final myId = SupabaseService.currentUser?.id;

      for (final row in data) {
        final userId = row['user_id'] as String;
        if (userId == myId) continue;

        final lat = (row['lat'] as num?)?.toDouble();
        final lng = (row['lng'] as num?)?.toDouble();
        final lastSeen = DateTime.tryParse(row['last_seen'] as String? ?? '');

        if (lat == null || lng == null || lastSeen == null) continue;

        _presenceMap[userId] = _UserPresenceEntry(
          lat: lat,
          lng: lng,
          lastSeen: lastSeen,
        );
      }

      _rebuildHexCells();
      debugPrint(
          '🔥 Heatmap: Fetched ${_presenceMap.length} active users');
    } catch (e) {
      debugPrint('❌ Heatmap: Failed to fetch presence: $e');
    }
  }

  

  void _subscribeToRealtime() {
    _unsubscribeRealtime();

    _realtimeChannel = SupabaseService.client.channel('heatmap-presence');

    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_presence',
          callback: (payload) => _handlePresenceChange(payload),
        )
        .subscribe((status, [error]) {
      debugPrint('🔥 Heatmap RT: channel status=$status');
    });
  }

  void _unsubscribeRealtime() {
    if (_realtimeChannel != null) {
      try {
        SupabaseService.client.removeChannel(_realtimeChannel!);
      } catch (e) {
        debugPrint('HeatmapService: removeChannel error — $e');
      }
      _realtimeChannel = null;
    }
  }

  void _handlePresenceChange(PostgresChangePayload payload) {
    final myId = SupabaseService.currentUser?.id;

    
    if (payload.eventType == PostgresChangeEvent.delete) {
      final oldRecord = payload.oldRecord;
      final userId = oldRecord['user_id'] as String?;
      if (userId != null && userId != myId) {
        final removed = _presenceMap.remove(userId);
        if (removed != null) {
          _rebuildHexCells();
          debugPrint('🔥 Heatmap: User $userId went OFFLINE (deleted)');
        }
      }
      return;
    }

    
    final newRecord = payload.newRecord;
    if (newRecord.isEmpty) return;

    final userId = newRecord['user_id'] as String?;
    if (userId == null || userId == myId) return;

    final lat = (newRecord['lat'] as num?)?.toDouble();
    final lng = (newRecord['lng'] as num?)?.toDouble();
    final lastSeenStr = newRecord['last_seen'] as String?;
    final lastSeen = DateTime.tryParse(lastSeenStr ?? '');

    if (lat == null || lng == null || lastSeen == null) return;

    _presenceMap[userId] = _UserPresenceEntry(
      lat: lat,
      lng: lng,
      lastSeen: lastSeen,
    );

    _rebuildHexCells();

    final eventName = payload.eventType == PostgresChangeEvent.insert
        ? 'ONLINE'
        : 'MOVED';
    debugPrint('🔥 Heatmap: User $userId $eventName at ($lat, $lng)');
  }

  

  
  void _startStaleCleanup() {
    _staleCleanupTimer?.cancel();
    _staleCleanupTimer = Timer.periodic(
      const Duration(seconds: 60),
      (_) => _cleanupStaleEntries(),
    );
  }

  void _cleanupStaleEntries() {
    final cutoff = DateTime.now().toUtc().subtract(_staleDuration);
    final staleUserIds = <String>[];

    _presenceMap.forEach((userId, entry) {
      if (entry.lastSeen.isBefore(cutoff)) {
        staleUserIds.add(userId);
      }
    });

    if (staleUserIds.isEmpty) return;

    for (final id in staleUserIds) {
      _presenceMap.remove(id);
    }

    _rebuildHexCells();
    debugPrint(
        '🔥 Heatmap: Cleaned ${staleUserIds.length} stale users, '
        '${_presenceMap.length} remaining');
  }

  

  
  
  
  Timer? _rebuildDebounce;

  void _rebuildHexCells() {
    if (_presenceMap.isEmpty) {
      _currentCells = [];
      _heatmapController.add(_currentCells);
      return;
    }

    _rebuildDebounce?.cancel();
    _rebuildDebounce = Timer(const Duration(milliseconds: 100), _computeHexCells);
  }

  void _computeHexCells() {
    if (_isDisposed) return;
    
    final cellCounts = <String, _HexCellAccumulator>{};

    for (final entry in _presenceMap.values) {
      final hexCenter = snapToHexGrid(entry.lat, entry.lng, hexRadiusMeters);
      final cellId =
          '${hexCenter.lat.toStringAsFixed(5)}_${hexCenter.lng.toStringAsFixed(5)}';

      if (cellCounts.containsKey(cellId)) {
        cellCounts[cellId]!.count++;
      } else {
        cellCounts[cellId] = _HexCellAccumulator(
          count: 1,
          centerLat: hexCenter.lat,
          centerLng: hexCenter.lng,
        );
      }
    }

    
    int maxCount = 1;
    for (final acc in cellCounts.values) {
      if (acc.count > maxCount) maxCount = acc.count;
    }

    _currentCells = cellCounts.entries.map((entry) {
      final acc = entry.value;
      final intensity = (acc.count / maxCount).clamp(0.0, 1.0);

      return HeatmapCell(
        cellId: entry.key,
        centerLat: acc.centerLat,
        centerLng: acc.centerLng,
        userCount: acc.count,
        intensity: intensity,
        level: _intensityLevel(acc.count),
      );
    }).toList();

    _heatmapController.add(_currentCells);
  }

  

  
  
  
  
  
  
  
  
  static ({double lat, double lng}) snapToHexGrid(
      double lat, double lng, double radiusMeters) {
    const metersPerDegreeLat = 111320.0;
    final metersPerDegreeLng =
        111320.0 * math.cos(lat * math.pi / 180.0);

    final radiusLat = radiusMeters / metersPerDegreeLat;
    final radiusLng = radiusMeters / metersPerDegreeLng;

    
    final colWidth = radiusLng * math.sqrt(3);
    final rowHeight = radiusLat * 1.5;

    
    final row = (lat / rowHeight).round();
    
    final lngOffset = (row % 2 == 0) ? 0.0 : colWidth / 2.0;
    final col = ((lng - lngOffset) / colWidth).round();

    
    final snappedLng = col * colWidth + lngOffset;
    final snappedLat = row * rowHeight;

    return (lat: snappedLat, lng: snappedLng);
  }

  
  static HeatmapLevel _intensityLevel(int count) {
    if (count >= 10) return HeatmapLevel.high;
    if (count >= 5) return HeatmapLevel.medium;
    return HeatmapLevel.low;
  }
}



class _UserPresenceEntry {
  final double lat;
  final double lng;
  final DateTime lastSeen;

  const _UserPresenceEntry({
    required this.lat,
    required this.lng,
    required this.lastSeen,
  });
}

class _HexCellAccumulator {
  int count;
  final double centerLat;
  final double centerLng;

  _HexCellAccumulator({
    required this.count,
    required this.centerLat,
    required this.centerLng,
  });
}




class HeatmapCell {
  final String cellId;
  final double centerLat;
  final double centerLng;
  final int userCount;
  final double intensity; 
  final HeatmapLevel level;

  const HeatmapCell({
    required this.cellId,
    required this.centerLat,
    required this.centerLng,
    required this.userCount,
    required this.intensity,
    required this.level,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HeatmapCell &&
          other.cellId == cellId &&
          other.userCount == userCount;

  @override
  int get hashCode => Object.hash(cellId, userCount);
}


enum HeatmapLevel {
  
  high,

  
  medium,

  
  low,
}
