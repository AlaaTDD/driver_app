
import 'package:flutter/foundation.dart';
import '../../../../../services/supabase_service.dart';



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

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) {
        return const CouponResult.error('errorInvalidCoupon');
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
      debugPrint('❌ CouponRepository: validateCoupon failed: $e');
      debugPrint(stackTrace.toString());
      return const CouponResult.error('errorApplyCoupon');
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
