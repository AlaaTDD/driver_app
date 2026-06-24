import 'package:equatable/equatable.dart';

class BonusRuleModel extends Equatable {
  final String id;
  final String name;
  final String? nameAr;
  final String triggerType;
  final int threshold;
  final double bonusAmount;
  final bool isActive;
  final List<String> vehicleTypes;
  final String? serviceAreaId;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final int tripsCompleted;
  final bool alreadyAwarded;

  const BonusRuleModel({
    required this.id,
    this.name = '',
    this.nameAr,
    this.triggerType = 'daily_trips',
    this.threshold = 0,
    this.bonusAmount = 0,
    this.isActive = true,
    this.vehicleTypes = const [],
    this.serviceAreaId,
    this.startsAt,
    this.expiresAt,
    this.tripsCompleted = 0,
    this.alreadyAwarded = false,
  });

  factory BonusRuleModel.fromJson(Map<String, dynamic> json) {
    return BonusRuleModel(
      id: (json['rule_id'] ?? json['id'])?.toString() ?? '',
      name: json['name'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      triggerType: json['trigger_type'] as String? ?? 'daily_trips',
      threshold: _asInt(json['threshold']),
      bonusAmount: _asDouble(json['bonus_amount']),
      isActive: json['is_active'] as bool? ?? true,
      vehicleTypes: _stringList(json['vehicle_types']),
      serviceAreaId: json['service_area_id'] as String?,
      startsAt: _date(json['starts_at']),
      expiresAt: _date(json['expires_at']),
      tripsCompleted: _asInt(json['trips_completed']),
      alreadyAwarded: json['already_awarded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rule_id': id,
        'name': name,
        'name_ar': nameAr,
        'trigger_type': triggerType,
        'threshold': threshold,
        'bonus_amount': bonusAmount,
        'is_active': isActive,
        'vehicle_types': vehicleTypes,
        'service_area_id': serviceAreaId,
        'starts_at': startsAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'trips_completed': tripsCompleted,
        'already_awarded': alreadyAwarded,
      };

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

  static List<String> _stringList(Object? value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return const [];
  }

  @override
  List<Object?> get props => [
        id,
        name,
        nameAr,
        triggerType,
        threshold,
        bonusAmount,
        isActive,
        vehicleTypes,
        serviceAreaId,
        startsAt,
        expiresAt,
        tripsCompleted,
        alreadyAwarded,
      ];
}
