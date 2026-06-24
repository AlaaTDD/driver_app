import 'package:snapix/core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class RatingRepository {
  final _client = SupabaseService.client;

  /// Fetch trip info to know the driver and if rating already submitted
  Future<Map<String, dynamic>?> getTripData(String tripId) async {
    try {
      return await _client
          .from('trips')
          .select(
              'user_id, driver_id, user_rating_to_driver, driver_rating_to_user')
          .eq('id', tripId)
          .single();
    } catch (e) {
      AppLogger.error('RatingRepository: Failed to get trip data: $e');
      return null;
    }
  }

  /// Check if the current user has already rated this trip
  Future<bool> hasExistingRating(String tripId, String currentUserId,
      String tripUserId, String tripDriverId) async {
    final isDriver = currentUserId == tripDriverId;
    try {
      if (isDriver) {
        final existing = await _client
            .from('user_ratings')
            .select('id')
            .eq('trip_id', tripId)
            .eq('driver_id', currentUserId)
            .maybeSingle();
        return existing != null;
      } else {
        final existing = await _client
            .from('ratings')
            .select('id')
            .eq('trip_id', tripId)
            .eq('user_id', currentUserId)
            .maybeSingle();
        return existing != null;
      }
    } catch (e) {
      AppLogger.debug(
          '⚠️ RatingRepository: Failed to check existing rating table: $e');
      // Fallback to checking the trips table directly if the ratings tables fail or don't exist
      try {
        final trip = await getTripData(tripId);
        if (trip == null) return false;
        if (isDriver) {
          return trip['driver_rating_to_user'] != null;
        } else {
          return trip['user_rating_to_driver'] != null;
        }
      } catch (e2) {
        return false;
      }
    }
  }

  /// Submit rating:
  /// 1. Inserts into `ratings` table → triggers `_fn_recalculate_driver_rating`
  ///    which auto-updates `users.rating` (DB-side, no Flutter code needed).
  /// 2. Marks `trips.user_rating_to_driver` so we know rating was submitted.
  Future<void> submitRating({
    required String tripId,
    required String currentUserId,
    required String tripUserId,
    required String tripDriverId,
    required int rating,
    String? comment,
  }) async {
    final isDriver = currentUserId == tripDriverId;

    if (isDriver) {
      // Driver is rating the user
      await _client.from('user_ratings').insert({
        'trip_id': tripId,
        'driver_id': currentUserId,
        'user_id': tripUserId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });

      await _client
          .from('trips')
          .update({'driver_rating_to_user': rating}).eq('id', tripId);
    } else {
      // User is rating the driver
      await _client.from('ratings').insert({
        'trip_id': tripId,
        'user_id': currentUserId,
        'driver_id': tripDriverId,
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      });

      try {
        await _client
            .from('trips')
            .update({'user_rating_to_driver': rating}).eq('id', tripId);
      } catch (e) {
        AppLogger.debug(
            '⚠️ RatingRepository: Could not mark trip user_rating_to_driver field: $e');
      }
    }
  }
}
