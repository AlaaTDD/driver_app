import 'package:snapix/core/models/trip_details_model.dart';
import 'package:snapix/core/models/driver_info_model.dart';
import 'package:snapix/features/trips/data/models/trip_model.dart';
import 'package:snapix/core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class TripsRepository {
  final _client = SupabaseService.client;

  Future<List<TripModel>> loadUserTrips(String userId) async {
    final data = await _client
        .from('trips')
        .select(
            'id, user_id, driver_id, status, price, service_tier_name_snapshot, pickup_address, destination_address, pickup_lat, pickup_lng, destination_lat, destination_lng, distance_km, payment_method, cancel_reason, created_at, user_rating_to_driver, driver_rating_to_user')
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    return (data as List)
        .map((e) => TripModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<Map<String, DriverInfoModel>> fetchDriverDetails(
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
          .select(
              'id, vehicle_category, vehicle_plate, vehicle_model, vehicle_color')
          .inFilter('id', driverIds),
    ]);

    final usersData = results[0] as List;
    final profilesData = results[1] as List;

    final mergedMap = <String, Map<String, dynamic>>{};
    for (final user in usersData) {
      mergedMap[user['id']] = Map<String, dynamic>.from(user);
    }

    for (final profile in profilesData) {
      final id = profile['id'] as String;
      if (mergedMap.containsKey(id)) {
        mergedMap[id]!['vehicle_type'] = profile['vehicle_category'];
        mergedMap[id]!['vehicle_plate'] = profile['vehicle_plate'];
        mergedMap[id]!['vehicle_model'] = profile['vehicle_model'];
        mergedMap[id]!['vehicle_color'] = profile['vehicle_color'];
      }
    }

    return mergedMap.map(
      (id, json) => MapEntry(id, DriverInfoModel.fromJson(json)),
    );
  }

  Future<TripDetailsModel?> loadTripDetails(String tripId) async {
    final data = await _client
        .from('trips')
        .select(
            'id, user_id, driver_id, status, price, service_tier_name_snapshot, pickup_address, destination_address, pickup_lat, pickup_lng, destination_lat, destination_lng, distance_km, estimated_duration_min, payment_method, payment_source, cancel_reason, cancel_reason_category, cancelled_by, meeting_lat, meeting_lng, meeting_address, geohash, scheduled_at, created_at, user_rating_to_driver, driver_rating_to_user')
        .eq('id', tripId)
        .single();
    return TripDetailsModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<DriverInfoModel?> fetchSingleDriverDetails(
      String driverId) async {
    try {
      final driverData = await _client
          .from('users')
          .select('id, name, avatar_url, phone, rating')
          .eq('id', driverId)
          .single();
      return DriverInfoModel.fromJson(Map<String, dynamic>.from(driverData));
    } catch (e) {
      AppLogger.warning('TripsRepository: Could not fetch driver details: $e');
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
      AppLogger.error(
          'TripsRepository: Failed to get trip for cancellation: $e');
      return null;
    }
  }

  Future<void> cancelTrip(
    String tripId,
    String userId, {
    String? cancelReason,
    String? cancelReasonCategory,
  }) async {
    bool cancelled = false;

    // ── Attempt 1: RPC ──
    try {
      await _client.rpc(
        'cancel_trip',
        params: {
          'p_trip_id': tripId,
          'p_user_id': userId,
          'p_cancelled_by': 'user',
          if (cancelReason != null) 'p_cancel_reason': cancelReason,
          if (cancelReasonCategory != null)
            'p_cancel_reason_category': cancelReasonCategory,
        },
      );
      cancelled = true;
    } catch (e, st) {
      AppLogger.debug(
          '⚠️ TripsRepository: cancel_trip RPC failed ($e) — trying DB check');
      AppLogger.debug(st.toString());
    }

    // ── Check DB Status ──
    if (!cancelled) {
      try {
        final row = await _client
            .from('trips')
            .select('status')
            .eq('id', tripId)
            .maybeSingle();
        if (row != null && row['status'] == 'cancelled') {
          cancelled = true;
        } else {
          AppLogger.debug(
              '⚠️ TripsRepository: DB check did not confirm cancellation for $tripId (status=${row?['status']})');
        }
      } catch (e, st) {
        AppLogger.debug(
            '❌ TripsRepository: DB cancellation verification failed for $tripId: $e');
        AppLogger.debug(st.toString());
        throw Exception('Failed to verify cancelled trip status');
      }
    }

    if (!cancelled) {
      throw Exception('Failed to cancel trip: cancellation was not confirmed');
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
