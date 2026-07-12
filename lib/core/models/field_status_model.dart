/// حالة حقل واحد داخل طلب المراجعة.
///
/// تُخزَّن في `driver_revision_requests.field_statuses` كـ JSONB:
/// ```json
/// {
///   "national_id": { "status": "requires_action", "reason": "...", ... }
/// }
/// ```
class FieldStatusModel {
  /// اسم الحقل كما هو في DB (مثل `national_id`, `license_image_url`)
  final String fieldKey;

  /// `pending` | `requires_action` | `approved`
  final String status;

  /// سبب طلب التعديل — لا يظهر إذا كان `approved`
  final String? reason;

  /// وقت آخر مراجعة من المشرف
  final DateTime? reviewedAt;

  /// معرف المشرف الذي راجع هذا الحقل
  final String? reviewedBy;

  const FieldStatusModel({
    required this.fieldKey,
    required this.status,
    this.reason,
    this.reviewedAt,
    this.reviewedBy,
  });

  bool get isPending      => status == 'pending';
  bool get isApproved     => status == 'approved';
  bool get requiresAction => status == 'requires_action';

  factory FieldStatusModel.fromJson(String fieldKey, Map<String, dynamic> json) {
    return FieldStatusModel(
      fieldKey:   fieldKey,
      status:     json['status'] as String? ?? 'pending',
      reason:     json['reason'] as String?,
      reviewedAt: _date(json['reviewed_at']),
      reviewedBy: json['reviewed_by'] as String?,
    );
  }

  /// Fallback لو لم يكن field_statuses موجوداً بعد (بيانات قديمة)
  factory FieldStatusModel.pendingFallback(String fieldKey, String? reason) {
    return FieldStatusModel(
      fieldKey: fieldKey,
      status:   'pending',
      reason:   reason,
    );
  }

  Map<String, dynamic> toJson() => {
    'status':      status,
    'reason':      reason,
    'reviewed_at': reviewedAt?.toIso8601String(),
    'reviewed_by': reviewedBy,
  };

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
