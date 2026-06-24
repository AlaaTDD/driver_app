import 'package:equatable/equatable.dart';

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

  const RevisionRequestModel({
    required this.id,
    this.driverId,
    this.message,
    this.status = 'pending',
    this.fieldsRequested = const [],
    this.fieldName,
    this.createdAt,
  });

  factory RevisionRequestModel.fromJson(Map<String, dynamic> json) {
    final rawFields = json['fields_requested'];
    final fields = rawFields is List
        ? rawFields.map((e) => e.toString()).toList()
        : <String>[];

    return RevisionRequestModel(
      id: json['id']?.toString() ?? '',
      driverId: json['driver_id'] as String?,
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      fieldsRequested: fields,
      fieldName: json['field_name'] as String?,
      createdAt: _date(json['created_at']),
    );
  }

  bool get isResolved => status == 'resolved';

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        id, driverId, message, status, fieldsRequested, fieldName, createdAt,
      ];
}
