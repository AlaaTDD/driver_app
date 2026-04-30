// lib/features/shared/presentation/rating/data/rating_repository.dart
import 'package:flutter/foundation.dart';
import '../../../../../services/supabase_service.dart';

/// Repository for Rating operations.
/// Encapsulates all Supabase data access for trip rating features.
///
/// ARCHITECTURE NOTE:
/// The database has a trigger `_fn_recalculate_driver_rating` that
/// automatically recalculates the driver's average rating on INSERT
/// into the `ratings` table. Therefore, the client does NOT need to
/// manually calculate and update the average — the trigger handles it.
class RatingRepository {
  final _client = SupabaseService.client;

  /// Get trip data with driver_id and user_rating
  Future<Map<String, dynamic>?> getTripData(String tripId) async {
    try {
      return await _client
          .from('trips')
          .select('driver_id, user_rating_to_driver')
          .eq('id', tripId)
          .single();
    } catch (e) {
      debugPrint('❌ RatingRepository: Failed to get trip data: $e');
      return null;
    }
  }

  /// Check if user already rated this trip
  Future<bool> hasExistingRating(String tripId, String userId) async {
    try {
      final existing = await _client
          .from('ratings')
          .select('id')
          .eq('trip_id', tripId)
          .eq('user_id', userId)
          .maybeSingle();
      return existing != null;
    } catch (e) {
      debugPrint('❌ RatingRepository: Failed to check existing rating: $e');
      return false;
    }
  }

  /// Submit a rating.
  ///
  /// The database trigger `_fn_recalculate_driver_rating` automatically
  /// updates the driver's average rating in the `users` table.
  /// We do NOT need to manually query all ratings and calculate the average.
  Future<void> submitRating({
    required String tripId,
    required String userId,
    required String driverId,
    required int rating,
    String? comment,
  }) async {
    // 1. Insert rating record — the DB trigger will auto-update driver's avg
    await _client.from('ratings').insert({
      'trip_id': tripId,
      'user_id': userId,
      'driver_id': driverId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    });

    // 2. Update trip with user_rating_to_driver
    await _client
        .from('trips')
        .update({'user_rating_to_driver': rating})
        .eq('id', tripId);

    // NOTE: The driver's average rating in `users.rating` is now
    // automatically updated by the `_fn_recalculate_driver_rating` trigger.
    // No manual calculation needed — this eliminates the race condition
    // where two concurrent ratings could produce incorrect averages.
  }
}
