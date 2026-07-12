import 'package:snapix/core/utils/retry_helper.dart';
import 'package:snapix/core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class MeetingPointRepository {
  final _client = SupabaseService.client;

  Future<String?> getActiveTripId(String userId) async {
    final activeTrip = await _client
        .from('trips')
        .select('id')
        .eq('user_id', userId)
        .inFilter('status', [
      'scheduled',
      'searching',
      'accepted',
      'driver_arriving',
      'in_progress'
    ]).maybeSingle();
    return activeTrip?['id'] as String?;
  }

  Future<void> cancelTrip(String tripId) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    bool cancelled = false;

    // ── Attempt 1: RPC ──
    try {
      await _client.rpc(
        'cancel_trip',
        params: {
          'p_trip_id': tripId,
          'p_user_id': userId,
          'p_cancelled_by': 'user',
        },
      );
      cancelled = true;
    } catch (e, st) {
      AppLogger.debug(
          '⚠️ MeetingPointRepository: cancel_trip RPC failed ($e) — trying DB check');
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
              '⚠️ MeetingPointRepository: DB check did not confirm cancellation for $tripId (status=${row?['status']})');
        }
      } catch (e, st) {
        AppLogger.debug(
            '❌ MeetingPointRepository: DB cancellation verification failed for $tripId: $e');
        AppLogger.debug(st.toString());
        throw Exception('Failed to verify cancelled trip status');
      }
    }

    if (!cancelled) {
      throw Exception('Failed to cancel trip: cancellation was not confirmed');
    }
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
    String? serviceTierId, // Phase 3: service_tiers UUID
    required String paymentMethod,
    String? geohash,
    String? couponCode,
    double? meetingLat,
    double? meetingLng,
    String? meetingAddress,
    double? estimatedDurationMin,
    DateTime? scheduledAt, // Fix #16
  }) async {
    final isScheduled =
        scheduledAt != null && scheduledAt.isAfter(DateTime.now());
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
      if (serviceTierId != null && serviceTierId.isNotEmpty)
        'service_tier_id': serviceTierId,
      'payment_method': paymentMethod,
      'payment_source': paymentMethod == 'wallet' ? 'wallet' : 'cash',
      'status': isScheduled ? 'scheduled' : 'searching',
      if (geohash != null) 'geohash': geohash,
      if (meetingLat != null) 'meeting_lat': meetingLat,
      if (meetingLng != null) 'meeting_lng': meetingLng,
      if (meetingAddress != null) 'meeting_address': meetingAddress,
      if (estimatedDurationMin != null)
        'estimated_duration_min': estimatedDurationMin,
      if (isScheduled) 'scheduled_at': scheduledAt.toIso8601String(),
    };

    final result = await withRetry<Map<String, dynamic>>(
      () => _client.from('trips').insert(tripData).select('id').single(),
      maxAttempts: 3,
      onRetry: (e, attempt) =>
          AppLogger.debug('Trip insert attempt $attempt failed: $e'),
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
        AppLogger.debug('🎫 Coupon applied: $couponResult');
      } catch (e) {
        AppLogger.debug(
            '🚨 MeetingPointRepository: Coupon failed — rolling back trip: $e');
        // Roll back through the same cancellation RPC so triggers and wallet
        // side effects stay consistent.
        try {
          await _client.rpc(
            'cancel_trip',
            params: {
              'p_trip_id': result['id'],
              'p_user_id': userId,
              'p_cancelled_by': 'user',
              'p_cancel_reason': 'coupon_apply_failed',
            },
          );
        } catch (rollbackErr) {
          AppLogger.warning('Rollback also failed: $rollbackErr');
        }
        // Rethrow so the calling Bloc/UI shows a user-friendly error
        // and the user can retry the trip creation.
        rethrow;
      }
    }

    return result;
  }
}
