
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/coupon_entity.dart';
import '../../domain/repositories/coupon_repository.dart';
import '../models/coupon_model.dart';
import '../models/user_coupon_model.dart';

class CouponRepositoryImpl implements CouponRepository {
  final SupabaseClient _client;

  CouponRepositoryImpl(this._client);

  @override
  Future<CouponEntity?> validateCoupon(String code) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client.rpc('validate_coupon', params: {
        'p_code': code,
        'p_trip_price': 0, 
        'p_user_id': userId,
      });

      final List<dynamic> data = response as List<dynamic>;
      if (data.isEmpty) return null;

      final row = data.first as Map<String, dynamic>;
      
      return CouponEntity(
        id: row['id'] as String,
        code: code,
        discountType: row['discount_type'] as String,
        discountValue: (row['discount_value'] as num).toDouble(),
        minTripPrice: 0,
        maxUses: 1,
        usedCount: 0,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        isActive: true,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<UserCouponModel>> getUserCoupons(String userId) async {
    try {
      final response = await _client
          .from('user_coupons')
          .select('*, coupons(*)')
          .eq('user_id', userId)
          .order('assigned_at', ascending: false);

      return response.map((json) => UserCouponModel.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<UserCouponModel> assignCouponToUser(String userId, String couponId) async {
    final response = await _client.from('user_coupons').insert({
      'user_id': userId,
      'coupon_id': couponId,
    }).select('*, coupons(*)').single();

    return UserCouponModel.fromJson(response);
  }

  @override
  Future<void> markCouponAsUsed(String userCouponId) async {
    await _client.from('user_coupons').update({
      'used_at': DateTime.now().toIso8601String(),
      'is_used': true,
    }).eq('id', userCouponId);
  }
}
