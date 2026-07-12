import 'package:flutter/material.dart';
import '../localization/generated/app_localizations.dart';

/// ══════════════════════════════════════════════════════════════
/// FormValidators — دوال تحقق موحَّدة لحقول التسجيل (الاسم، البريد
/// الإلكتروني، كلمة المرور) لتفادي تكرار المنطق بين شاشتي تسجيل
/// الراكب والسائق (register_user_screen.dart / register_driver_screen.dart)،
/// ولضمان اتساق رسائل الخطأ بينهما.
///
/// الاستخدام:
///   TextFormField(
///     validator: (v) => FormValidators.name(context, v),
///   )
/// ══════════════════════════════════════════════════════════════
class FormValidators {
  FormValidators._();

  // حدود متوافقة مع أعمدة قاعدة البيانات الفعلية (Supabase):
  //   users.name  → varchar(255)
  //   users.email → varchar(255)
  static const int nameMinLength = 2;
  static const int nameMaxLength = 255;
  static const int emailMaxLength = 255;
  static const int passwordMinLength = 6;
  static const int passwordMaxLength = 72; // حد bcrypt العملي الشائع

  // حدود بيانات السائق — لا يوجد ملف migrations SQL محلي موثّق لحدود
  // drivers_profile الفعلية في قاعدة البيانات وقت كتابة هذا الكود، لذا استُخدمت
  // حدود آمنة معقولة (كافية لأي بيانات حقيقية، وكافية لمنع إدخال غير منطقي أو
  // Payload ضخم عبر هذه الحقول) بدلاً من اختراع أرقام محددة بلا مصدر.
  static const int nationalIdLength = 14; // الرقم القومي المصري: 14 رقمًا بالضبط
  static const int licenseNumberMinLength = 3;
  static const int licenseNumberMaxLength = 50;
  static const int vehicleTextMinLength = 2; // للماركة/الموديل/اللون
  static const int vehicleTextMaxLength = 100;
  static const int vehiclePlateMinLength = 2;
  static const int vehiclePlateMaxLength = 20;
  static const int minVehicleYear = 1990;

  /// يقبل الحروف العربية (بما فيها الحركات) والحروف اللاتينية والمسافات
  /// والشرطة والفاصلة العليا فقط — يرفض الأرقام وبقية الرموز.
  static final RegExp _nameAllowedChars = RegExp(
    r"^[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFFa-zA-Z\s'\-]+$",
  );

  static String? name(BuildContext context, String? value) {
    final l = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l.enterFullName;
    }
    final trimmed = value.trim();
    if (trimmed.length < nameMinLength) {
      return l.nameTooShort;
    }
    if (trimmed.length > nameMaxLength) {
      return l.nameTooLong;
    }
    if (!_nameAllowedChars.hasMatch(trimmed)) {
      return l.nameInvalidChars;
    }
    return null;
  }

  /// يحافظ على السلوك الحالي بالضبط: يقبل اسم مستخدم بدون "@" (سيُستكمل
  /// لاحقًا تلقائيًا عبر normalizeEmailInput في email_utils.dart)، أو
  /// بريدًا إلكترونيًا كاملاً بأي مزوّد.
  static String? email(BuildContext context, String? value) {
    final l = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return l.enterEmail;
    }
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return l.enterEmail;
    }
    if (trimmed.contains(' ')) {
      return l.emailContainsSpaces;
    }
    if (trimmed.length > emailMaxLength) {
      return l.emailInvalidLength;
    }
    if (trimmed.contains('@')) {
      if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(trimmed)) {
        return l.invalidEmailFormat;
      }
    } else {
      if (!RegExp(r'^[\w.-]+$').hasMatch(trimmed)) {
        return l.invalidEmailFormat;
      }
    }
    return null;
  }

  static String? password(BuildContext context, String? value) {
    final l = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return l.enterPassword;
    }
    if (value.length < passwordMinLength) {
      return l.passwordMinLength;
    }
    if (value.length > passwordMaxLength) {
      return l.passwordMaxLength;
    }
    return null;
  }

  static String? confirmPassword(
    BuildContext context,
    String? value,
    String originalPassword,
  ) {
    final l = AppLocalizations.of(context)!;
    if (value == null || value.isEmpty) {
      return l.pleaseConfirmPassword;
    }
    if (value != originalPassword) {
      return l.passwordsNotMatch;
    }
    return null;
  }

  /// الرقم القومي المصري: 14 رقمًا بالضبط، أرقام فقط.
  static String? nationalId(BuildContext context, String? value) {
    final l = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l.enterNationalId;
    }
    final trimmed = value.trim();
    if (!RegExp(r'^[0-9]+$').hasMatch(trimmed)) {
      return l.nationalIdInvalidFormat;
    }
    if (trimmed.length != nationalIdLength) {
      return l.nationalIdInvalidLength;
    }
    return null;
  }

  /// رقم رخصة القيادة: يقبل أرقامًا وحروفًا عربية/لاتينية وشرطة فقط (لا رموز
  /// أخرى)، بحد أدنى وأقصى للطول لمنع إدخال فارغ فعليًا أو نص ضخم غير منطقي.
  static String? licenseNumber(BuildContext context, String? value) {
    final l = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l.enterLicenseNumber;
    }
    final trimmed = value.trim();
    if (trimmed.length < licenseNumberMinLength) {
      return l.licenseNumberTooShort;
    }
    if (trimmed.length > licenseNumberMaxLength) {
      return l.licenseNumberTooLong;
    }
    if (!_nameAllowedChars.hasMatch(trimmed) &&
        !RegExp(r'^[0-9\u0600-\u06FFa-zA-Z\s\-]+$').hasMatch(trimmed)) {
      return l.licenseNumberInvalidChars;
    }
    return null;
  }

  /// حقول نصية عامة لبيانات المركبة (الماركة/الموديل/اللون) — تتحقق من الوجود
  /// والحدود الدنيا/القصوى للطول فقط؛ تُستخدم دالة موحدة لضمان اتساق السلوك.
  static String? _vehicleText(
    BuildContext context,
    String? value,
    String emptyMessage,
    String tooShortMessage,
    String tooLongMessage,
  ) {
    if (value == null || value.trim().isEmpty) {
      return emptyMessage;
    }
    final trimmed = value.trim();
    if (trimmed.length < vehicleTextMinLength) {
      return tooShortMessage;
    }
    if (trimmed.length > vehicleTextMaxLength) {
      return tooLongMessage;
    }
    return null;
  }

  static String? vehicleBrand(BuildContext context, String? value) {
    final l = AppLocalizations.of(context)!;
    return _vehicleText(context, value, l.enterVehicleBrand,
        l.vehicleBrandTooShort, l.vehicleBrandTooLong);
  }

  static String? vehicleModel(BuildContext context, String? value) {
    final l = AppLocalizations.of(context)!;
    return _vehicleText(context, value, l.enterVehicleModel,
        l.vehicleModelTooShort, l.vehicleModelTooLong);
  }

  static String? vehicleColor(BuildContext context, String? value) {
    final l = AppLocalizations.of(context)!;
    return _vehicleText(context, value, l.enterVehicleColor,
        l.vehicleColorTooShort, l.vehicleColorTooLong);
  }

  /// رقم لوحة السيارة: يقبل أرقامًا وحروفًا عربية ومسافات فقط (نمط مرن يغطي
  /// تنسيقات اللوحات المصرية المختلفة دون رفض لوحات صحيحة عن طريق الخطأ)،
  /// برفض الرموز والفراغات الزائدة وبحد أقصى معقول للطول.
  static String? vehiclePlate(BuildContext context, String? value) {
    final l = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l.enterPlateNumber;
    }
    final trimmed = value.trim();
    if (trimmed.length < vehiclePlateMinLength) {
      return l.plateNumberTooShort;
    }
    if (trimmed.length > vehiclePlateMaxLength) {
      return l.plateNumberTooLong;
    }
    if (!RegExp(r'^[0-9\u0600-\u06FFa-zA-Z\s]+$').hasMatch(trimmed)) {
      return l.plateNumberInvalidChars;
    }
    if (!RegExp(r'[0-9]').hasMatch(trimmed)) {
      // لوحة السيارة لازم تحتوي على رقم واحد على الأقل — نص عربي/لاتيني بحت
      // بدون أي أرقام مش لوحة سيارة صحيحة منطقيًا.
      return l.plateNumberInvalidFormat;
    }
    return null;
  }

  /// سنة صنع المركبة: رقم صحيح بين 1990 والسنة الحالية (يمنع سيارات وهمية أو
  /// إدخال سنوات مستقبلية). نُقلت من منطق كان inline داخل الشاشة لتوحيد المصدر.
  static String? vehicleYear(BuildContext context, String? value) {
    final l = AppLocalizations.of(context)!;
    if (value == null || value.trim().isEmpty) {
      return l.enterVehicleYear;
    }
    final year = int.tryParse(value.trim());
    if (year == null || year < minVehicleYear || year > DateTime.now().year) {
      return l.enterValidYear;
    }
    return null;
  }
}
