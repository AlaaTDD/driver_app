// lib/features/driver/presentation/trip_details/data/trip_details_repository.dart
import 'package:flutter/foundation.dart';
import '../../../../../services/supabase_service.dart';

/// Repository for Driver Trip Details operations.
/// Encapsulates all Supabase data access, extracted from TripDetailsBloc
/// to enforce Single Responsibility Principle.
class TripDetailsRepository {
  final _client = SupabaseService.client;

  /// The canonical SELECT query for trip details with user join.
  /// Used consistently across all trip-related operations.
  static const _tripSelectQuery =
      '*, user:users!trips_user_id_fkey(id, name, phone, rating, avatar_url)';

  /// Load full trip details with user info.
  Future<Map<String, dynamic>> loadTripDetails(String tripId) async {
    final data = await _client
        .from('trips')
        .select(_tripSelectQuery)
        .eq('id', tripId)
        .single();
    return Map<String, dynamic>.from(data);
  }

  /// Accept a trip via the atomic RPC function.
  /// Returns `{success: true}` or `{success: false, error: '...'}`.
  Future<Map<String, dynamic>?> acceptTrip(String tripId) async {
    return await _client.rpc(
      'driver_accept_trip',
      params: {'p_trip_id': tripId},
    );
  }

  /// Reject a trip offer (updates trip_offers only, NOT trips table).
  Future<void> rejectTripOffer({
    required String tripId,
    required String driverId,
  }) async {
    await _client
        .from('trip_offers')
        .update({
          'status': 'rejected',
          'responded_at': DateTime.now().toIso8601String(),
        })
        .eq('trip_id', tripId)
        .eq('driver_id', driverId);
  }

  /// Start a trip via the atomic RPC function.
  Future<Map<String, dynamic>?> startTrip({
    required String tripId,
    required String driverId,
  }) async {
    return await _client.rpc(
      'driver_start_trip',
      params: {'p_trip_id': tripId, 'p_driver_id': driverId},
    );
  }

  /// Complete a trip via the atomic RPC function.
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
