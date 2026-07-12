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

  /// الحد الأدنى للتقييم (نجوم) — مطلوب فقط عند triggerType == 'rating_threshold'.
  final double? minRating;

  /// UUIDs من service_tiers.id — الفئات التجارية المسموح للحافز أن يُحتسب على
  /// رحلاتها. يحل محل vehicleTypes في المنطق الجديد.
  final List<String> categoryIds;

  /// يفعّل تدفق طلب الاستلام اليدوي بدل الصرف التلقائي الفوري.
  final bool requiresClaim;

  /// حالة تحدي هذا السائق مع هذه القاعدة: notStarted/active/completed/
  /// claimPending/claimed. تأتي من get_my_bonus_progress، وليست خاصية ثابتة
  /// للقاعدة نفسها — لذلك افتراضيًا notStarted عند القراءة من فورم الإدارة.
  final String status;

  /// لحظة ضغط السائق على "ابدأ" لهذا التحدي في الفترة الحالية، إن وُجدت.
  final DateTime? startedAt;

  /// القيمة الحالية للتقدم: عدد رحلات منذ startedAt، أو التقييم الحالي عند
  /// rating_threshold.
  final double currentValue;

  /// الهدف المطلوب: threshold أو minRating بحسب triggerType.
  final double targetValue;

  /// نسبة التقدم 0-100، جاهزة للعرض المباشر في progress bar.
  final double progressPct;

  /// معرّف صف driver_bonus_progress المرتبط بهذا التحدي، إن كان قد بدأ.
  final String? progressId;

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
    this.minRating,
    this.categoryIds = const [],
    this.requiresClaim = true,
    this.status = 'not_started',
    this.startedAt,
    this.currentValue = 0,
    this.targetValue = 0,
    this.progressPct = 0,
    this.progressId,
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
      minRating: _asNullableDouble(json['min_rating']),
      categoryIds: _stringList(json['category_ids']),
      requiresClaim: json['requires_claim'] as bool? ?? true,
      status: json['status'] as String? ?? 'not_started',
      startedAt: _date(json['started_at']),
      currentValue: _asDouble(json['current_value']),
      targetValue: _asDouble(json['target_value']),
      progressPct: _asDouble(json['progress_pct']),
      progressId: json['progress_id']?.toString(),
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
        'min_rating': minRating,
        'category_ids': categoryIds,
        'requires_claim': requiresClaim,
        'status': status,
        'started_at': startedAt?.toIso8601String(),
        'current_value': currentValue,
        'target_value': targetValue,
        'progress_pct': progressPct,
        'progress_id': progressId,
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

  static double? _asNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
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

  /// نسخة من هذه القاعدة بحقول حالة محدَّثة (تُستخدم بعد استدعاء startBonusChallenge
  /// أو requestBonusClaim لتحديث الواجهة محلياً دون انتظار جولة get_my_bonus_progress
  /// كاملة أخرى).
  BonusRuleModel copyWithStatus({
    String? status,
    DateTime? startedAt,
    double? currentValue,
    double? progressPct,
    String? progressId,
  }) {
    return BonusRuleModel(
      id: id,
      name: name,
      nameAr: nameAr,
      triggerType: triggerType,
      threshold: threshold,
      bonusAmount: bonusAmount,
      isActive: isActive,
      vehicleTypes: vehicleTypes,
      serviceAreaId: serviceAreaId,
      startsAt: startsAt,
      expiresAt: expiresAt,
      tripsCompleted: tripsCompleted,
      alreadyAwarded: alreadyAwarded,
      minRating: minRating,
      categoryIds: categoryIds,
      requiresClaim: requiresClaim,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      currentValue: currentValue ?? this.currentValue,
      targetValue: targetValue,
      progressPct: progressPct ?? this.progressPct,
      progressId: progressId ?? this.progressId,
    );
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
        minRating,
        categoryIds,
        requiresClaim,
        status,
        startedAt,
        currentValue,
        targetValue,
        progressPct,
        progressId,
      ];
}
