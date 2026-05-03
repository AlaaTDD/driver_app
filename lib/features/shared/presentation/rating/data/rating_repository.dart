
import 'package:flutter/foundation.dart';
import '../../../../../services/supabase_service.dart';









class RatingRepository {
  final _client = SupabaseService.client;

  
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

  
  
  
  
  
  Future<void> submitRating({
    required String tripId,
    required String userId,
    required String driverId,
    required int rating,
    String? comment,
  }) async {
    
    await _client.from('ratings').insert({
      'trip_id': tripId,
      'user_id': userId,
      'driver_id': driverId,
      'rating': rating,
      if (comment != null) 'comment': comment,
    });

    
    await _client
        .from('trips')
        .update({'user_rating_to_driver': rating})
        .eq('id', tripId);

    
    
    
    
  }
}
