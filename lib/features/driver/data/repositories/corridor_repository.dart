import 'package:snapix/services/supabase_service.dart';

class CorridorData {
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;
  final double? originRadiusKm;
  final double? destRadiusKm;

  const CorridorData({
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
    this.originRadiusKm,
    this.destRadiusKm,
  });

  bool get isComplete =>
      originLat != null &&
      originLng != null &&
      destLat != null &&
      destLng != null;
}

/// Extracts all Supabase corridor DB calls from the UI layer.
class CorridorRepository {
  Future<CorridorData?> loadCorridor(String driverId) async {
    final row = await SupabaseService.client
        .from('drivers_profile')
        .select(
            'target_origin_lat, target_origin_lng, target_dest_lat, target_dest_lng, target_origin_radius_km, target_route_radius_km')
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
    );
  }

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
      });
    } catch (_) {
      // Fallback: direct write if RPC not found / signature changed
      await SupabaseService.client.from('drivers_profile').update({
        'target_origin_lat': data.originLat,
        'target_origin_lng': data.originLng,
        'target_dest_lat': data.destLat,
        'target_dest_lng': data.destLng,
        'target_origin_radius_km': data.originRadiusKm,
        'target_route_radius_km': data.destRadiusKm,
      }).eq('id', driverId);
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
    }).eq('id', driverId);
  }
}
