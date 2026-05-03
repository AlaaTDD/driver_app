
import 'package:equatable/equatable.dart';

class CouponModel extends Equatable {
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

  const CouponModel({
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

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      code: json['code'] as String,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      minTripPrice: json['min_trip_price'] != null
          ? (json['min_trip_price'] as num).toDouble()
          : null,
      maxUses: json['max_uses'] as int?,
      usedCount: json['used_count'] as int,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_trip_price': minTripPrice,
      'max_uses': maxUses,
      'used_count': usedCount,
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
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
