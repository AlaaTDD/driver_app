
import 'package:flutter/foundation.dart';
import '../../../../../services/supabase_service.dart';




class TripDetailsRepository {
  final _client = SupabaseService.client;

  
  
  static const _tripSelectQuery =
      '*, user:users!trips_user_id_fkey(id, name, phone, rating, avatar_url)';

  
  Future<Map<String, dynamic>> loadTripDetails(String tripId) async {
    final data = await _client
        .from('trips')
        .select(_tripSelectQuery)
        .eq('id', tripId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  
  
  Future<Map<String, dynamic>?> acceptTrip(String tripId) async {
    return await _client.rpc(
      'driver_accept_trip',
      params: {'p_trip_id': tripId},
    );
  }

  
  Future<void> rejectTripOffer({
    required String tripId,
    required String driverId,
  }) async {
    await _client.rpc(
      'driver_reject_trip',
      params: {'p_trip_id': tripId},
    );
  }

  
  Future<Map<String, dynamic>?> startTrip({
    required String tripId,
    required String driverId,
  }) async {
    return await _client.rpc(
      'driver_start_trip',
      params: {'p_trip_id': tripId, 'p_driver_id': driverId},
    );
  }

  
  Future<Map<String, dynamic>?> completeTrip({
    required String tripId,
    required String driverId,
  }) async {
    return await _client.rpc(
      'driver_complete_trip',
      params: {'p_trip_id': tripId, 'p_driver_id': driverId},
    );
  }
}
