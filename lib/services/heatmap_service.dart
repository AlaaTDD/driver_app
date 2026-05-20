import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class HeatmapService {
  HeatmapService._();
  static final HeatmapService instance = HeatmapService._();

  static const double hexRadiusMeters = 300.0;

  RealtimeChannel? _presenceChannel;
  bool _isDisposed = false;

  final _heatmapController = StreamController<List<HeatmapCell>>.broadcast();

  Stream<List<HeatmapCell>> get heatmapUpdates => _heatmapController.stream;

  final Map<String, _UserPresenceEntry> _presenceMap = {};

  List<HeatmapCell> _currentCells = [];

  List<HeatmapCell> get currentCells => List.unmodifiable(_currentCells);

  Future<void> startRealtimeUpdates() async {
    _isDisposed = false; // Allow restarting after sign-out

    if (_presenceChannel != null) {
      if (!_heatmapController.isClosed) {
        _heatmapController.add(List.unmodifiable(_currentCells));
      }
      debugPrint(
          '🔥 Heatmap: Already connected — pushed ${_currentCells.length} cells to new subscriber');
      return;
    }

    _subscribeToPresenceChanges();
    await _fetchAllPresence();
  }

  void stopRealtimeUpdates() {
    final channel = _presenceChannel;
    _presenceChannel = null;
    if (channel != null) {
      SupabaseService.client.removeChannel(channel);
    }
    _presenceMap.clear();
    _currentCells = [];
    if (!_heatmapController.isClosed) {
      _heatmapController.add([]);
    }
  }

  void dispose() {
    _isDisposed = true;
    stopRealtimeUpdates();
    // Do NOT close _heatmapController because this is a Singleton.
    // If user signs out and signs back in, the stream must still be open.
    if (!_heatmapController.isClosed) {
      _heatmapController.add([]); // Emit empty to clear map
    }
  }

  Future<void> _fetchAllPresence() async {
    try {
      final data = await SupabaseService.client
          .from('user_presence')
          .select('user_id, lat, lng');

      _presenceMap.clear();

      final myId = SupabaseService.currentUser?.id;

      for (final row in data) {
        final userId = row['user_id'] as String;
        if (userId == myId) continue;

        final lat = (row['lat'] as num?)?.toDouble();
        final lng = (row['lng'] as num?)?.toDouble();

        if (lat == null || lng == null) continue;

        _presenceMap[userId] = _UserPresenceEntry(
          lat: lat,
          lng: lng,
        );
      }

      _rebuildHexCells();
      debugPrint('🔥 Heatmap: Loaded ${_presenceMap.length} presence rows');
    } catch (e) {
      debugPrint('❌ Heatmap: Failed to fetch presence: $e');
    }
  }

  void _subscribeToPresenceChanges() {
    final channel = SupabaseService.client
        .channel('heatmap-user-presence')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_presence',
          callback: _handlePresencePayload,
        )
        .subscribe((status, [error]) {
      debugPrint('🔥 Heatmap: Realtime status=$status error=$error');
    });

    _presenceChannel = channel;
  }

  void _handlePresencePayload(PostgresChangePayload payload) {
    if (_isDisposed) return;

    if (payload.eventType == PostgresChangeEvent.delete) {
      final userId = payload.oldRecord['user_id'] as String?;
      if (userId != null && _presenceMap.remove(userId) != null) {
        _rebuildHexCells();
      }
      return;
    }

    final row = payload.newRecord;
    final userId = row['user_id'] as String?;
    if (userId == null) return;

    if (userId == SupabaseService.currentUser?.id) {
      if (_presenceMap.remove(userId) != null) _rebuildHexCells();
      return;
    }

    final lat = (row['lat'] as num?)?.toDouble();
    final lng = (row['lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return;

    _presenceMap[userId] = _UserPresenceEntry(lat: lat, lng: lng);
    _rebuildHexCells();
  }

  void _rebuildHexCells() {
    if (_presenceMap.isEmpty) {
      _currentCells = [];
      _heatmapController.add(_currentCells);
      return;
    }

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
    final metersPerDegreeLng = 111320.0 * math.cos(lat * math.pi / 180.0);

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

  const _UserPresenceEntry({
    required this.lat,
    required this.lng,
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
