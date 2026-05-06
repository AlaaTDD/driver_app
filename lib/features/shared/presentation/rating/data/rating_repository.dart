
import 'package:flutter/foundation.dart';
import '../../../../../services/supabase_service.dart';

class RatingRepository {
  final _client = SupabaseService.client;

  /// Fetch trip info to know the driver and if rating already submitted
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

  /// Check if the current user has already rated this trip
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

  /// Submit rating:
  /// 1. Inserts into `ratings` table → triggers `_fn_recalculate_driver_rating`
  ///    which auto-updates `users.rating` (DB-side, no Flutter code needed).
  /// 2. Marks `trips.user_rating_to_driver` so we know rating was submitted.
  Future<void> submitRating({
    required String tripId,
    required String userId,
    required String driverId,
    required int rating,
    String? comment,
  }) async {
    // Step 1: Insert into ratings — DB trigger auto-recalculates driver's average rating
    await _client.from('ratings').insert({
      'trip_id': tripId,
      'user_id': userId,
      'driver_id': driverId,
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });

    // Step 2: Mark the trip so UI knows a rating was submitted for this trip
    try {
      await _client
          .from('trips')
          .update({'user_rating_to_driver': rating})
          .eq('id', tripId);
    } catch (e) {
      // Non-critical: rating was already submitted, just trip mark failed
      debugPrint('⚠️ RatingRepository: Could not mark trip rating field: $e');
    }
  }
}
