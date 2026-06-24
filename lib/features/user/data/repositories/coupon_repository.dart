import 'package:snapix/core/services/supabase_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class CouponRepository {
  final _client = SupabaseService.client;

  Future<CouponResult> validateCoupon({
    required String couponCode,
    required double originalPrice,
    required String userId,
  }) async {
    try {
      final normalizedCode = couponCode.trim().toUpperCase();

      final response = await _client.rpc(
        'validate_coupon',
        params: {
          'p_code': normalizedCode,
          'p_trip_price': originalPrice,
          'p_user_id': userId,
        },
      );

      final data = response as List;
      if (data.isEmpty) {
        // Fallback: If Postgres returned empty, manually figure out why for a better error message.
        final specificError = await _getDetailedCouponError(
          couponCode: normalizedCode,
          originalPrice: originalPrice,
          userId: userId,
        );
        return CouponResult.error(specificError);
      }

      final row = data.first as Map<String, dynamic>;
      final discountAmount = (row['discount_amount'] as num).toDouble();

      final finalPrice = originalPrice - discountAmount;

      return CouponResult.success(
        couponCode: normalizedCode,
        discount: discountAmount,
        finalPrice: finalPrice,
      );
    } catch (e, stackTrace) {
      AppLogger.error('CouponRepository: validateCoupon failed: $e');
      AppLogger.debug(stackTrace.toString());
      return const CouponResult.error('errorApplyCoupon');
    }
  }

  Future<String> _getDetailedCouponError({
    required String couponCode,
    required double originalPrice,
    required String userId,
  }) async {
    try {
      final couponData = await _client
          .from('coupons')
          .select()
          .eq('code', couponCode)
          .eq('is_active', true)
          .maybeSingle();

      if (couponData == null) {
        return 'errorInvalidCoupon';
      }

      final now = DateTime.now().toUtc();

      if (couponData['starts_at'] != null) {
        final start = DateTime.parse(couponData['starts_at']);
        if (now.isBefore(start)) return 'errorCouponNotStarted';
      }

      if (couponData['expires_at'] != null) {
        final expiry = DateTime.parse(couponData['expires_at']);
        if (now.isAfter(expiry)) return 'errorCouponExpired';
      }

      if (couponData['max_uses'] != null && couponData['used_count'] != null) {
        if ((couponData['used_count'] as int) >= (couponData['max_uses'] as int)) {
          return 'errorCouponMaxUsesReached';
        }
      }

      if (couponData['min_trip_price'] != null) {
        if (originalPrice < (couponData['min_trip_price'] as num).toDouble()) {
          return 'errorCouponMinTripPriceNotMet';
        }
      }

      if (couponData['budget_limit'] != null && couponData['spent_budget'] != null) {
        if ((couponData['spent_budget'] as num) >= (couponData['budget_limit'] as num)) {
          return 'errorCouponBudgetExhausted';
        }
      }

      if (couponData['first_ride_only'] == true) {
        final trips = await _client
            .from('trips')
            .select('id')
            .eq('user_id', userId)
            .eq('status', 'completed')
            .limit(1);
        if (trips.isNotEmpty) {
          return 'errorCouponFirstRideOnly';
        }
      }

      // If we got here and Postgres rejected it, it's either user limit reached or something else.
      return 'errorInvalidCoupon';
    } catch (e) {
      AppLogger.warning('CouponRepository: _getDetailedCouponError failed: $e');
      return 'errorInvalidCoupon';
    }
  }

  Future<void> assignCouponToUser(String couponCode, String userId) async {
    try {
      final coupon = await _client
          .from('coupons')
          .select('id')
          .eq('code', couponCode.trim().toUpperCase())
          .eq('is_active', true)
          .maybeSingle();
      
      if (coupon == null) return;

      await _client.from('user_coupons').insert({
        'user_id': userId,
        'coupon_id': coupon['id'],
      });
      AppLogger.info('CouponRepository: assigned $couponCode to user wallet');
    } catch (e) {
      AppLogger.warning('CouponRepository: assignCouponToUser failed (might already exist): $e');
    }
  }
}

class CouponResult {
  final bool isSuccess;
  final String? couponCode;
  final double? discount;
  final double? finalPrice;
  final String? errorKey;

  const CouponResult._({
    required this.isSuccess,
    this.couponCode,
    this.discount,
    this.finalPrice,
    this.errorKey,
  });

  const CouponResult.success({
    required String couponCode,
    required double discount,
    required double finalPrice,
  }) : this._(
          isSuccess: true,
          couponCode: couponCode,
          discount: discount,
          finalPrice: finalPrice,
        );

  const CouponResult.error(String errorKey)
      : this._(isSuccess: false, errorKey: errorKey);
}
