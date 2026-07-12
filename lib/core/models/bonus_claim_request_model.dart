import 'package:equatable/equatable.dart';

/// يمثّل صفاً من bonus_claim_requests — طلب استلام مكافأة قدّمه السائق بعد
/// تحقيق شرط الحافز، بانتظار موافقة/رفض الإدارة. بنفس نمط طلبات السحب
/// (withdrawal_requests) الموجودة مسبقاً في المشروع.
class BonusClaimRequestModel extends Equatable {
  final String id;
  final String bonusRuleId;
  final String? driverBonusProgressId;
  final double bonusAmount;
  final int tripsCounted;
  final String status;
  final DateTime? requestedAt;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  const BonusClaimRequestModel({
    required this.id,
    required this.bonusRuleId,
    this.driverBonusProgressId,
    this.bonusAmount = 0,
    this.tripsCounted = 0,
    this.status = 'pending',
    this.requestedAt,
    this.reviewedAt,
    this.rejectionReason,
  });

  factory BonusClaimRequestModel.fromJson(Map<String, dynamic> json) {
    return BonusClaimRequestModel(
      id: (json['claim_id'] ?? json['id'])?.toString() ?? '',
      bonusRuleId: (json['bonus_rule_id'] ?? json['rule_id'])?.toString() ?? '',
      driverBonusProgressId: json['driver_bonus_progress_id']?.toString() ??
          json['progress_id']?.toString(),
      bonusAmount: _asDouble(json['bonus_amount']),
      tripsCounted: _asInt(json['trips_counted']),
      status: json['status'] as String? ?? 'pending',
      requestedAt: _date(json['requested_at']),
      reviewedAt: _date(json['reviewed_at']),
      rejectionReason: json['rejection_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'claim_id': id,
        'bonus_rule_id': bonusRuleId,
        'driver_bonus_progress_id': driverBonusProgressId,
        'bonus_amount': bonusAmount,
        'trips_counted': tripsCounted,
        'status': status,
        'requested_at': requestedAt?.toIso8601String(),
        'reviewed_at': reviewedAt?.toIso8601String(),
        'rejection_reason': rejectionReason,
      };

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        id,
        bonusRuleId,
        driverBonusProgressId,
        bonusAmount,
        tripsCounted,
        status,
        requestedAt,
        reviewedAt,
        rejectionReason,
      ];
}
