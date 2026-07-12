import 'package:equatable/equatable.dart';

import 'bonus_rule_model.dart';

/// غلاف حول نتيجة get_my_bonus_progress الجديدة. الدالة تُرجع الآن **كل**
/// القواعد النشطة المتاحة للسائق، كل واحدة بحالتها المستقلة (محمولة داخل
/// الحقول الجديدة في BonusRuleModel: status/startedAt/currentValue/progressPct)،
/// بدل قاعدة واحدة مختارة ورقم تقدم عام واحد (selectedRuleId القديم).
///
/// تم الإبقاء على الحقول القديمة (currentTrips/requiredTrips/progressPercent) للتوافق
/// مع أي كود قديم لا يزال يقرأها، لكن المنطق الجديد (bonus_cubit وbonus_screen)
/// يستخدم `bonuses` حصرياً لعرض كل تحدٍ بحالته المستقلة.
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
    final bonuses = json['bonuses'] is List
        ? (json['bonuses'] as List)
            .whereType<Map>()
            .map((e) => BonusRuleModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
        : const <BonusRuleModel>[];

    // الحقول المسطحة القديمة (currentTrips/requiredTrips) لم تعد تُرسل من
    // get_my_bonus_progress الجديدة إطلاقًا. نبقيها صفرية آمنة للتوافق مع أي
    // مستهلك قديم لم يزال يقرأها، بدل من تخمينها من أول قاعدة في `bonuses`
    // (والذي كان يفترض ضمنيًا قاعدة واحدة مختارة فقط).
    return BonusProgressModel(
      driverId: json['driver_id'] as String?,
      currentTrips: _asInt(json['trips_today']),
      requiredTrips: 0,
      bonusAmount: 0,
      triggerType: 'daily_trips',
      progressPercent: 0,
      bonuses: bonuses,
    );
  }

  Map<String, dynamic> toJson() => {
        'driver_id': driverId,
        'trips_today': currentTrips,
        'bonuses': bonuses.map((e) => e.toJson()).toList(),
      };

  /// عدد المهام النشطة حالياً (status الة active أو completed) — يستخدمه
  /// _buildProgressCard لعرض ملخص عام بدل تفاصيل قاعدة واحدة.
  int get activeChallengesCount =>
      bonuses.where((b) => b.status == 'active' || b.status == 'completed').length;

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
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
