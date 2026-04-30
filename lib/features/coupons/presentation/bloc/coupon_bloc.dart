// lib/features/coupons/presentation/bloc/coupon_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/coupon_repository.dart';
import 'coupon_event.dart';
import 'coupon_state.dart';

class CouponBloc extends Bloc<CouponEvent, CouponState> {
  final CouponRepository _repository;

  CouponBloc(this._repository) : super(CouponInitial()) {
    on<LoadUserCoupons>(_onLoadUserCoupons);
    on<ValidateCoupon>(_onValidateCoupon);
    on<ApplyCoupon>(_onApplyCoupon);
  }

  Future<void> _onLoadUserCoupons(
    LoadUserCoupons event,
    Emitter<CouponState> emit,
  ) async {
    emit(CouponLoading());
    try {
      final coupons = await _repository.getUserCoupons(event.userId);
      emit(UserCouponsLoaded(coupons));
    } catch (e) {
      emit(const CouponError('errorLoadCoupons'));
    }
  }

  Future<void> _onValidateCoupon(
    ValidateCoupon event,
    Emitter<CouponState> emit,
  ) async {
    emit(CouponLoading());
    try {
      final coupon = await _repository.validateCoupon(event.code);
      if (coupon == null) {
        emit(const CouponError('errorInvalidCoupon'));
      } else {
        emit(CouponValidated(coupon, 0));
      }
    } catch (e) {
      emit(const CouponError('errorVerifyCoupon'));
    }
  }

  Future<void> _onApplyCoupon(
    ApplyCoupon event,
    Emitter<CouponState> emit,
  ) async {
    try {
      final coupon = await _repository.validateCoupon(event.couponCode);
      if (coupon == null) {
        emit(const CouponError('errorInvalidCoupon'));
        return;
      }

      final discount = coupon.calculateDiscount(event.originalPrice);
      final discountedPrice = event.originalPrice - discount;

      emit(CouponValidated(coupon, discountedPrice));
    } catch (e) {
      emit(const CouponError('errorApplyCoupon'));
    }
  }
}
