
import 'package:flutter/foundation.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../../core/utils/retry_helper.dart';


class MeetingPointRepository {
  final _client = SupabaseService.client;

  
  Future<bool> hasActiveTrip(String userId) async {
    final activeTrip = await _client
        .from('trips')
        .select('id')
        .eq('user_id', userId)
        .inFilter('status', ['searching', 'accepted', 'in_progress'])
        .maybeSingle();
    return activeTrip != null;
  }

  
  Future<Map<String, dynamic>> createTrip({
    required String userId,
    required double pickupLat,
    required double pickupLng,
    required String pickupAddress,
    required double destLat,
    required double destLng,
    required String destAddress,
    required double distanceKm,
    required double price,
    required String vehicleType,
    required String paymentMethod,
    String? geohash,
    String? couponCode,
  }) async {
    final tripData = <String, dynamic>{
      'user_id': userId,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'pickup_address': pickupAddress,
      'destination_lat': destLat,
      'destination_lng': destLng,
      'destination_address': destAddress,
      'distance_km': distanceKm,
      'price': price,
      'vehicle_type': vehicleType,
      'payment_method': paymentMethod,
      'status': 'searching',
      if (geohash != null) 'geohash': geohash,
    };

    final result = await withRetry<Map<String, dynamic>>(
      () => _client
          .from('trips')
          .insert(tripData)
          .select('id')
          .single(),
      maxAttempts: 3,
      onRetry: (e, attempt) => debugPrint('Trip insert attempt $attempt failed: $e'),
    );

    
    if (couponCode != null && couponCode.isNotEmpty) {
      try {
        await _client.rpc('use_coupon_atomic', params: {
          'p_user_id': userId,
          'p_coupon_code': couponCode,
          'p_trip_id': result['id'],
        });
      } catch (e) {
        debugPrint('⚠️ MeetingPointRepository: Failed to record coupon usage: $e');
      }
    }

    return result;
  }
}
