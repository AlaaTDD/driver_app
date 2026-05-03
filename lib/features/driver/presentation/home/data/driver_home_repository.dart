
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

  
  Future<double> getTotalEarnings(String userId) async {
    try {
      final earningsData = await _client
          .from('driver_earnings_summary')
          .select('total_earnings')
          .eq('driver_id', userId)
          .maybeSingle();
      if (earningsData != null) {
        return (earningsData['total_earnings'] as num?)?.toDouble() ?? 0;
      }
    } catch (e) {
      debugPrint('⚠️ DriverHomeRepository: earnings view failed, using fallback: $e');
      
      
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      final tripsData = await _client
          .from('trips')
          .select('price')
          .eq('driver_id', userId)
          .eq('status', 'completed')
          .gte('completed_at', cutoff.toIso8601String())
          .order('completed_at', ascending: false)
          .limit(500);
      double totalEarnings = 0;
      for (final trip in (tripsData as List)) {
        totalEarnings += (trip['price'] as num?)?.toDouble() ?? 0;
      }
      return totalEarnings;
    }
    return 0;
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

    await _client.rpc('upsert_driver_location', params: {
      'p_driver_id': userId,
      'p_lat': lat,
      'p_lng': lng,
      'p_heading': heading ?? 0.0,
      'p_geohash': geohash,
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
