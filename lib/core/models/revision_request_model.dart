import 'package:equatable/equatable.dart';
import 'field_status_model.dart';

/// Model for a driver revision request from the `driver_revision_requests` table.
///
/// Used by [DriverRevisionCubit] / [DriverRevisionScreen] /
/// [PendingVerificationScreen].
class RevisionRequestModel extends Equatable {
  final String id;
  final String? driverId;
  final String? message;
  final String status;
  final List<String> fieldsRequested;
  final String? fieldName;
  final DateTime? createdAt;

  /// حالة كل حقل بشكل مستقل — المصدر الحقيقي للحالة التفصيلية.
  /// فارغ للبيانات القديمة (قبل الـ migration) — يُعامَل كـ fallback.
  final Map<String, FieldStatusModel> fieldStatuses;

  /// آخر مشرف راجع الطلب
  final String? reviewedBy;

  /// تاريخ آخر تحديث على الطلب
  final DateTime? updatedAt;

  const RevisionRequestModel({
    required this.id,
    this.driverId,
    this.message,
    this.status = 'pending',
    this.fieldsRequested = const [],
    this.fieldName,
    this.createdAt,
    this.fieldStatuses = const {},
    this.reviewedBy,
    this.updatedAt,
  });

  factory RevisionRequestModel.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields_requested'];
    final fields = rawFields is List
        ? rawFields.map((e) => e.toString()).toList()
        : <String>[];

    // بناء fieldStatuses من عمود JSONB الجديد
    final Map<String, FieldStatusModel> fieldStatuses = {};
    final rawStatuses = json['field_statuses'];
    if (rawStatuses is Map) {
      for (final entry in rawStatuses.entries) {
        final key = entry.key.toString();
        final val = entry.value;
        if (val is Map<String, dynamic>) {
          fieldStatuses[key] = FieldStatusModel.fromJson(key, val);
        }
      }
    }

    // Fallback: إذا field_statuses فارغ (بيانات قديمة)، نبني من fields_requested
    if (fieldStatuses.isEmpty && fields.isNotEmpty) {
      for (final f in fields) {
        fieldStatuses[f] = FieldStatusModel.pendingFallback(f, json['message'] as String?);
      }
    }

    return RevisionRequestModel(
      id:              json['id']?.toString() ?? '',
      driverId:        json['driver_id'] as String?,
      message:         json['message'] as String?,
      status:          json['status'] as String? ?? 'pending',
      fieldsRequested: fields,
      fieldName:       json['field_name'] as String?,
      createdAt:       _date(json['created_at']),
      fieldStatuses:   fieldStatuses,
      reviewedBy:      json['reviewed_by'] as String?,
      updatedAt:       _date(json['updated_at']),
    );
  }

  bool get isResolved => status == 'resolved';

  /// هل يوجد حقول تحتاج إجراء من السائق
  bool get hasActionRequired =>
      fieldStatuses.values.any((f) => f.requiresAction);

  /// قائمة الحقول التي تحتاج تعديلاً
  List<FieldStatusModel> get actionRequiredFields =>
      fieldStatuses.values.where((f) => f.requiresAction).toList();

  /// قائمة الحقول المعتمدة
  List<FieldStatusModel> get approvedFields =>
      fieldStatuses.values.where((f) => f.isApproved).toList();

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        id, driverId, message, status, fieldsRequested,
        fieldName, createdAt, fieldStatuses, reviewedBy, updatedAt,
      ];
}
