// lib/features/coupons/data/models/coupon_usage_model.dart
import 'package:equatable/equatable.dart';

class CouponUsageModel extends Equatable {
  final String id;
  final String tripId;
  final String userCouponId;
  final double discountAmount;
  final DateTime createdAt;

  const CouponUsageModel({
    required this.id,
    required this.tripId,
    required this.userCouponId,
    required this.discountAmount,
    required this.createdAt,
  });

  factory CouponUsageModel.fromJson(Map<String, dynamic> json) {
    return CouponUsageModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      userCouponId: json['user_coupon_id'] as String,
      discountAmount: (json['discount_amount'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'user_coupon_id': userCouponId,
      'discount_amount': discountAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, tripId, userCouponId, discountAmount, createdAt];
}
