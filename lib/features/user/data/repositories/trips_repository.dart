
import 'package:flutter/foundation.dart';
import '../../../../../services/supabase_service.dart';



class TripsRepository {
  final _client = SupabaseService.client;

  
  Future<List<Map<String, dynamic>>> loadUserTrips(String userId) async {
    final data = await _client
        .from('trips')
        .select('*')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  
  
  Future<Map<String, Map<String, dynamic>>> fetchDriverDetails(
    List<String> driverIds,
  ) async {
    if (driverIds.isEmpty) return {};

    
    final results = await Future.wait([
      _client
          .from('users')
          .select('id, name, avatar_url, phone, rating')
          .inFilter('id', driverIds),
      _client
          .from('driver_public_profile')
          .select('id, vehicle_type, vehicle_plate, vehicle_model, vehicle_color')
          .inFilter('id', driverIds),
    ]);

    final usersData = results[0] as List;
    final profilesData = results[1] as List;

    final driversMap = <String, Map<String, dynamic>>{};
    for (final user in usersData) {
      driversMap[user['id']] = Map<String, dynamic>.from(user);
    }
    
    for (final profile in profilesData) {
      final id = profile['id'] as String;
      if (driversMap.containsKey(id)) {
        driversMap[id]!['vehicle_type'] = profile['vehicle_type'];
        driversMap[id]!['vehicle_plate'] = profile['vehicle_plate'];
        driversMap[id]!['vehicle_model'] = profile['vehicle_model'];
        driversMap[id]!['vehicle_color'] = profile['vehicle_color'];
      }
    }

    return driversMap;
  }

  
  Future<Map<String, dynamic>?> loadTripDetails(String tripId) async {
    final data = await _client
        .from('trips')
        .select('*')
        .eq('id', tripId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  
  Future<Map<String, dynamic>?> fetchSingleDriverDetails(String driverId) async {
    try {
      final driverData = await _client
          .from('users')
          .select('id, name, avatar_url, phone, rating')
          .eq('id', driverId)
          .single();
      return Map<String, dynamic>.from(driverData);
    } catch (e) {
      debugPrint('⚠️ TripsRepository: Could not fetch driver details: $e');
      return null;
    }
  }

  
  Future<Map<String, dynamic>?> getTripForCancellation(String tripId) async {
    try {
      return await _client
          .from('trips')
          .select('status, user_id')
          .eq('id', tripId)
          .single();
    } catch (e) {
      debugPrint('❌ TripsRepository: Failed to get trip for cancellation: $e');
      return null;
    }
  }

  
  
  Future<void> cancelTrip(
    String tripId,
    String userId, {
    String? cancelReason,
    String? cancelReasonCategory,
  }) async {
    try {
      await _client.rpc(
        'cancel_trip',
        params: {
          'p_trip_id': tripId,
          'p_user_id': SupabaseService.currentUser!.id,
          'p_cancelled_by': 'user',
          if (cancelReason != null) 'p_cancel_reason': cancelReason,
        },
      );

      // Update structured category separately if provided
      if (cancelReasonCategory != null) {
        await _client
            .from('trips')
            .update({'cancel_reason_category': cancelReasonCategory})
            .eq('id', tripId);
      }
    } catch (e) {
      debugPrint('❌ TripsRepository: Failed to cancel trip: $e');
      rethrow;
    }
  }

  
  Future<void> submitComplaint({
    required String? userId,
    required String tripId,
    required String title,
    required String description,
  }) async {
    await _client.from('complaints').insert({
      'user_id': userId,
      'trip_id': tripId,
      'title': title,
      'description': description,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
