
import '../entities/coupon_entity.dart';
import '../../data/models/user_coupon_model.dart';

abstract class CouponRepository {
  Future<CouponEntity?> validateCoupon(String code);
  Future<List<UserCouponModel>> getUserCoupons(String userId);
  Future<UserCouponModel> assignCouponToUser(String userId, String couponId);
  Future<void> markCouponAsUsed(String userCouponId);
}
