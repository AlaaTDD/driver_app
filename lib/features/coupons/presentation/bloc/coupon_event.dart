// lib/features/coupons/presentation/bloc/coupon_event.dart
import 'package:equatable/equatable.dart';

abstract class CouponEvent extends Equatable {
  const CouponEvent();

  @override
  List<Object?> get props => [];
}

class LoadUserCoupons extends CouponEvent {
  final String userId;

  const LoadUserCoupons(this.userId);

  @override
  List<Object?> get props => [userId];
}

class ValidateCoupon extends CouponEvent {
  final String code;

  const ValidateCoupon(this.code);

  @override
  List<Object?> get props => [code];
}

// FIX H14: Renamed from couponId to couponCode — validateCoupon expects a code, not UUID
class ApplyCoupon extends CouponEvent {
  final String couponCode;
  final double originalPrice;

  const ApplyCoupon(this.couponCode, this.originalPrice);

  @override
  List<Object?> get props => [couponCode, originalPrice];
}
