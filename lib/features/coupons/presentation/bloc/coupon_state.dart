
import 'package:equatable/equatable.dart';
import '../../data/models/user_coupon_model.dart';
import '../../domain/entities/coupon_entity.dart';

abstract class CouponState extends Equatable {
  const CouponState();

  @override
  List<Object?> get props => [];
}

class CouponInitial extends CouponState {}

class CouponLoading extends CouponState {}

class UserCouponsLoaded extends CouponState {
  final List<UserCouponModel> coupons;

  const UserCouponsLoaded(this.coupons);

  @override
  List<Object?> get props => [coupons];
}

class CouponValidated extends CouponState {
  final CouponEntity coupon;
  final double discountedPrice;

  const CouponValidated(this.coupon, this.discountedPrice);

  @override
  List<Object?> get props => [coupon, discountedPrice];
}

class CouponError extends CouponState {
  final String message;

  const CouponError(this.message);

  @override
  List<Object?> get props => [message];
}
