
import 'package:flutter/foundation.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../../core/utils/geohash_helper.dart';
import '../../../../../features/trips/data/models/trip_model.dart';



class DriverHomeRepository {
  final _client = SupabaseService.client;

  
  Future<Map<String, dynamic>> loadDriverStatus(String userId) async {
    final results = await Future.wait([
      _client
          .from('drivers_profile')
          .select('is_available')
          .eq('id', userId)
          .single(),
      _client
          .from('users')
          .select('rating, total_trips')
          .eq('id', userId)
          .single(),
    ]);

    return {
      'driverData': results[0],
      'userData': results[1],
    };
  }

  
  Future<Map<String, dynamic>> getEarningsSummary(String userId) async {
    try {
      final data = await _client
          .from('driver_earnings_summary')
          .select()
          .eq('driver_id', userId)
          .single();
      return {
        'totalEarnings': (data['total_earnings'] as num?)?.toDouble() ?? 0,
        'availableBalance': (data['available_balance'] as num?)?.toDouble() ?? 0,
        'earningsThisWeek': (data['earnings_this_week'] as num?)?.toDouble() ?? 0,
        'earningsLast30Days': (data['earnings_last_30_days'] as num?)?.toDouble() ?? 0,
        'completedTrips': (data['completed_trips'] as int?) ?? 0,
      };
    } catch (e) {
      debugPrint('⚠️ getEarningsSummary failed: $e');
      return {
        'totalEarnings': 0.0,
        'availableBalance': 0.0,
        'earningsThisWeek': 0.0,
        'earningsLast30Days': 0.0,
        'completedTrips': 0,
      };
    }
  }

  
  Future<void> setDriverOnline(
    String userId,
    double lat,
    double lng,
  ) async {
    final geohash = GeohashHelper.encode(lat, lng);
    final geohash5 = GeohashHelper.encode(lat, lng, precision: 5);

    await _client.rpc('set_driver_online', params: {
      'p_driver_id': userId,
      'p_lat': lat,
      'p_lng': lng,
      'p_geohash': geohash,
      'p_geohash5': geohash5,
    });
  }

  
  Future<void> setDriverOffline(String userId) async {
    await _client.rpc('set_driver_offline', params: {
      'p_driver_id': userId,
    });
  }

  
  Future<void> pushLocation(
    String userId,
    double lat,
    double lng, {
    double? heading,
  }) async {
    final geohash = GeohashHelper.encode(lat, lng);
    final geohash5 = geohash.length > 5 ? geohash.substring(0, 5) : geohash;

    await _client.rpc('upsert_driver_location', params: {
      'p_driver_id': userId,
      'p_lat': lat,
      'p_lng': lng,
      'p_heading': heading ?? 0.0,
      'p_geohash': geohash,
      'p_geohash5': geohash5,
    });
  }

  
  Future<Map<String, dynamic>?> acceptTrip(String tripId) async {
    return await _client.rpc(
      'driver_accept_trip',
      params: {'p_trip_id': tripId},
    );
  }

  
  Future<Map<String, dynamic>?> rejectTrip(String tripId) async {
    return await _client.rpc(
      'driver_reject_trip',
      params: {'p_trip_id': tripId},
    );
  }

  
  Future<bool> hasActiveTrip(String userId) async {
    final activeTrips = await _client
        .from('trips')
        .select('id')
        .eq('driver_id', userId)
        .inFilter('status', ['accepted', 'in_progress'])
        .maybeSingle();
    return activeTrips != null;
  }

  
  Future<List<TripModel>> fetchTripsByIds(List<String> tripIds) async {
    if (tripIds.isEmpty) return [];
    final tripList = await _client
        .from('trips')
        .select('*, user:user_id(name, avatar_url, phone)')
        .inFilter('id', tripIds)
        .eq('status', 'searching');
    return (tripList as List)
        .map((e) => TripModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  
  Stream<List<Map<String, dynamic>>> getTripOffersStream(String userId) {
    return _client
        .from('trip_offers')
        .stream(primaryKey: ['id'])
        .eq('driver_id', userId);
  }
}
