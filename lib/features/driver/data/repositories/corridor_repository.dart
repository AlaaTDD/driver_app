import 'package:snapix/core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

/// Corridor mode: 'points' = two independent radius circles (origin/dest),
/// 'line' = an actual route polyline with a fixed width corridor.
enum CorridorMode { points, line }

extension CorridorModeX on CorridorMode {
  String toDbString() => this == CorridorMode.line ? 'line' : 'points';

  static CorridorMode fromDbString(String? value) {
    return value == 'line' ? CorridorMode.line : CorridorMode.points;
  }
}

class CorridorData {
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final double? originRadiusKm;
  final double? destRadiusKm;
  final CorridorMode mode;
  final String? polyline;
  final double? lineWidthKm;

  const CorridorData({
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    this.originRadiusKm,
    this.destRadiusKm,
    this.mode = CorridorMode.points,
    this.polyline,
    this.lineWidthKm,
  });

  bool get isComplete =>
      originLat != null &&
      originLng != null &&
      destLat != null &&
      destLng != null;

  /// In line mode, a corridor additionally requires a non-empty polyline.
  bool get isValidForMode =>
      isComplete && (mode == CorridorMode.points || (polyline?.isNotEmpty ?? false));
}

/// Extracts all Supabase corridor DB calls from the UI layer.
///
/// All writes go strictly through `set_driver_target_route` / the DB itself —
/// there is intentionally NO fallback that writes directly to `drivers_profile`
/// on RPC failure. A failed RPC must surface as a clear error to the driver,
/// never be silently masked by a direct write that bypasses the function's
/// validation (auth checks, mode/polyline consistency, etc).
class CorridorRepository {
  Future<CorridorData?> loadCorridor(String driverId) async {
    final row = await SupabaseService.client
        .from('drivers_profile')
        .select(
            'target_origin_lat, target_origin_lng, target_dest_lat, target_dest_lng, target_origin_radius_km, target_route_radius_km, corridor_mode, target_route_polyline, corridor_line_width_km')
        .eq('id', driverId)
        .maybeSingle();
    if (row == null) return null;
    return CorridorData(
      originLat: (row['target_origin_lat'] as num?)?.toDouble(),
      originLng: (row['target_origin_lng'] as num?)?.toDouble(),
      destLat: (row['target_dest_lat'] as num?)?.toDouble(),
      destLng: (row['target_dest_lng'] as num?)?.toDouble(),
      originRadiusKm: (row['target_origin_radius_km'] as num?)?.toDouble(),
      destRadiusKm: (row['target_route_radius_km'] as num?)?.toDouble(),
      mode: CorridorModeX.fromDbString(row['corridor_mode'] as String?),
      polyline: row['target_route_polyline'] as String?,
      lineWidthKm: (row['corridor_line_width_km'] as num?)?.toDouble(),
    );
  }

  /// Saves the corridor via the DB RPC. On failure this throws — callers
  /// must surface the error to the driver. There is no direct-write fallback:
  /// bypassing the RPC would skip its auth check and mode/polyline validation.
  Future<void> saveCorridor(String driverId, CorridorData data) async {
    try {
      await SupabaseService.client.rpc('set_driver_target_route', params: {
        'p_driver_id': driverId,
        'p_origin_lat': data.originLat,
        'p_origin_lng': data.originLng,
        'p_dest_lat': data.destLat,
        'p_dest_lng': data.destLng,
        'p_origin_radius_km': data.originRadiusKm,
        'p_dest_radius_km': data.destRadiusKm,
        'p_mode': data.mode.toDbString(),
        'p_polyline': data.polyline,
        'p_line_width_km': data.lineWidthKm,
      });
    } catch (e, st) {
      AppLogger.error('CorridorRepository: set_driver_target_route RPC failed: $e');
      AppLogger.debug(st.toString());
      // No fallback — rethrow so the UI can show a clear error to the driver.
      rethrow;
    }
  }

  Future<void> clearCorridor(String driverId) async {
    await SupabaseService.client.from('drivers_profile').update({
      'target_origin_lat': null,
      'target_origin_lng': null,
      'target_dest_lat': null,
      'target_dest_lng': null,
      'target_origin_radius_km': null,
      'target_route_radius_km': null,
      'corridor_mode': 'points',
      'target_route_polyline': null,
      'corridor_line_width_km': null,
      'target_route_active': false,
    }).eq('id', driverId);
  }
}
