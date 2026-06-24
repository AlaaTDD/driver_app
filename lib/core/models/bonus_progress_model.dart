import 'package:equatable/equatable.dart';

import 'bonus_rule_model.dart';

class BonusProgressModel extends Equatable {
  final String? driverId;
  final int currentTrips;
  final int requiredTrips;
  final double bonusAmount;
  final String triggerType;
  final double progressPercent;
  final List<BonusRuleModel> bonuses;

  const BonusProgressModel({
    this.driverId,
    this.currentTrips = 0,
    this.requiredTrips = 0,
    this.bonusAmount = 0,
    this.triggerType = 'daily_trips',
    this.progressPercent = 0,
    this.bonuses = const [],
  });

  factory BonusProgressModel.fromJson(Map<String, dynamic> json) {
    final currentTrips = _asInt(
      json['current_trips'] ?? json['trips_today'] ?? json['completed_trips'],
    );
    final requiredTrips = _asInt(json['required_trips'] ?? json['threshold']);
    final percent = json['progress_percent'] == null && requiredTrips > 0
        ? (currentTrips / requiredTrips * 100).clamp(0, 100).toDouble()
        : _asDouble(json['progress_percent']);
    final bonuses = json['bonuses'] is List
        ? (json['bonuses'] as List)
            .whereType<Map>()
            .map((e) => BonusRuleModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <BonusRuleModel>[];

    return BonusProgressModel(
      driverId: json['driver_id'] as String?,
      currentTrips: currentTrips,
      requiredTrips: requiredTrips,
      bonusAmount: _asDouble(json['bonus_amount']),
      triggerType: json['trigger_type'] as String? ?? 'daily_trips',
      progressPercent: percent,
      bonuses: bonuses,
    );
  }

  Map<String, dynamic> toJson() => {
        'driver_id': driverId,
        'current_trips': currentTrips,
        'trips_today': currentTrips,
        'required_trips': requiredTrips,
        'threshold': requiredTrips,
        'bonus_amount': bonusAmount,
        'trigger_type': triggerType,
        'progress_percent': progressPercent,
        'bonuses': bonuses.map((e) => e.toJson()).toList(),
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

  @override
  List<Object?> get props => [
        driverId,
        currentTrips,
        requiredTrips,
        bonusAmount,
        triggerType,
        progressPercent,
        bonuses,
      ];
}
