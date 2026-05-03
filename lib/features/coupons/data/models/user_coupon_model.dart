
import 'package:equatable/equatable.dart';
import 'coupon_model.dart';

class UserCouponModel extends Equatable {
  final String id;
  final String userId;
  final String couponId;
  final bool isUsed;
  final DateTime assignedAt;
  final DateTime? usedAt;

  final CouponModel coupon;

  const UserCouponModel({
    required this.id,
    required this.userId,
    required this.couponId,
    required this.isUsed,
    required this.assignedAt,
    this.usedAt,
    required this.coupon,
  });

  factory UserCouponModel.fromJson(Map<String, dynamic> json) {
    final usedAt = json['used_at'] != null
        ? DateTime.parse(json['used_at'] as String)
        : null;
    return UserCouponModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      couponId: json['coupon_id'] as String,
      isUsed: usedAt != null,
      assignedAt: DateTime.parse(json['assigned_at'] as String),
      usedAt: usedAt,
      coupon: CouponModel.fromJson(json['coupon'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'coupon_id': couponId,
      'assigned_at': assignedAt.toIso8601String(),
      'used_at': usedAt?.toIso8601String(),
      'coupon': coupon.toJson(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        couponId,
        isUsed,
        assignedAt,
        usedAt,
        coupon,
      ];
}
