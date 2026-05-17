
import 'package:flutter/foundation.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../../core/utils/retry_helper.dart';


class MeetingPointRepository {
  final _client = SupabaseService.client;

  Future<String?> getActiveTripId(String userId) async {
    final activeTrip = await _client
        .from('trips')
        .select('id')
        .eq('user_id', userId)
        .inFilter('status', ['searching', 'accepted', 'in_progress'])
        .maybeSingle();
    return activeTrip?['id'] as String?;
  }

  Future<void> cancelTrip(String tripId) async {
    await _client.rpc(
      'cancel_trip',
      params: {
        'p_trip_id': tripId,
        'p_user_id': SupabaseService.currentUser!.id,
        'p_cancelled_by': 'user',
      },
    );
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
    double? meetingLat,
    double? meetingLng,
    String? meetingAddress,
    double? estimatedDurationMin,
    DateTime? scheduledAt, // Fix #16
  }) async {
    final isScheduled = scheduledAt != null && scheduledAt.isAfter(DateTime.now());
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
      'status': isScheduled ? 'scheduled' : 'searching',
      if (geohash != null) 'geohash': geohash,
      if (meetingLat != null) 'meeting_lat': meetingLat,
      if (meetingLng != null) 'meeting_lng': meetingLng,
      if (meetingAddress != null) 'meeting_address': meetingAddress,
      if (estimatedDurationMin != null) 'estimated_duration_min': estimatedDurationMin,
      if (isScheduled) 'scheduled_at': scheduledAt!.toIso8601String(),
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

    // Apply coupon to the trip ATOMICALLY — if the coupon was promised to the
    // user and fails to apply, we must NOT silently charge full price.  Instead,
    // cancel the orphan trip and rethrow so the UI can show an error / retry.
    if (couponCode != null && couponCode.isNotEmpty) {
      try {
        final couponResult = await _client.rpc('apply_coupon_to_trip', params: {
          'p_trip_id': result['id'],
          'p_coupon_code': couponCode,
          'p_user_id': userId,
          'p_original_price': price,
        });
        debugPrint('🎫 Coupon applied: $couponResult');
      } catch (e) {
        debugPrint('🚨 MeetingPointRepository: Coupon failed — rolling back trip: $e');
        // Roll back: cancel the trip that was just created so the user
        // is not charged full price while expecting a discount.
        try {
          await _client.from('trips').delete().eq('id', result['id']);
        } catch (rollbackErr) {
          debugPrint('⚠️ Rollback also failed: $rollbackErr');
        }
        // Rethrow so the calling Bloc/UI shows a user-friendly error
        // and the user can retry the trip creation.
        rethrow;
      }
    }

    return result;
  }
}

