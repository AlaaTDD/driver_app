// lib/features/coupons/domain/entities/coupon_entity.dart
import 'package:equatable/equatable.dart';

class CouponEntity extends Equatable {
  final String id;
  final String code;
  final String discountType;
  final double discountValue;
  final double? minTripPrice;
  final int? maxUses;
  final int usedCount;
  final DateTime? expiresAt;
  final bool isActive;
  final DateTime createdAt;

  const CouponEntity({
    required this.id,
    required this.code,
    required this.discountType,
    required this.discountValue,
    this.minTripPrice,
    this.maxUses,
    required this.usedCount,
    this.expiresAt,
    required this.isActive,
    required this.createdAt,
  });

  bool get isValid {
    if (!isActive) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    if (maxUses != null && usedCount >= maxUses!) return false;
    return true;
  }

  double calculateDiscount(double originalPrice) {
    if (minTripPrice != null && originalPrice < minTripPrice!) return 0;
    
    if (discountType == 'percentage') {
      return originalPrice * (discountValue / 100);
    } else {
      return discountValue;
    }
  }

  @override
  List<Object?> get props => [
        id,
        code,
        discountType,
        discountValue,
        minTripPrice,
        maxUses,
        usedCount,
        expiresAt,
        isActive,
        createdAt,
      ];
}
