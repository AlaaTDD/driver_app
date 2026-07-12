import 'package:flutter/widgets.dart';

import '../localization/generated/app_localizations.dart';
import 'revision_request_model.dart';
import 'field_status_model.dart';

/// تسميات حقول طلب المراجعة — مصدر واحد مشترك بين جميع الشاشات.
extension RevisionRequestLabels on RevisionRequestModel {
  /// القائمة الجاهزة للعرض من `fieldsRequested` (أو `fieldName` كـ fallback).
  List<String> displayFields(BuildContext context) {
    final values = List<String>.from(fieldsRequested);
    if (values.isEmpty && fieldName != null) {
      values.add(fieldName!);
    }
    if (values.isEmpty) return [AppLocalizations.of(context)!.unspecified];
    return values.map((field) => fieldLabel(context, field)).toList();
  }

  /// تحويل اسم عمود خام إلى تسمية مُترجَمة قابلة للعرض للسائق.
  String fieldLabel(BuildContext context, String field) {
    final l = AppLocalizations.of(context)!;
    return switch (field) {
      'national_id'           => l.nationalId,
      'national_id_image_url' => l.nationalIdImage,
      'license_number'        => l.driverLicense,
      'license_image_url'     => l.licenseImage,
      'criminal_record_url'   => l.criminalRecord,
      'vehicle_type'          => l.vehicleType,
      'vehicle_brand'         => l.vehicleBrand,
      'vehicle_model'         => l.vehicleModel,
      'vehicle_year'          => l.vehicleYear,
      'vehicle_color'         => l.vehicleColor,
      'vehicle_plate'         => l.plateNumber,
      'vehicle_image_url'     => l.vehiclePhoto,
      _                       => field,
    };
  }
}

/// Extension على FieldStatusModel لترجمة الحالة
extension FieldStatusLabels on FieldStatusModel {
  /// أيقونة الحالة
  String get statusEmoji => switch (status) {
    'approved'        => '✅',
    'requires_action' => '⚠️',
    _                 => '⏳',
  };
}
