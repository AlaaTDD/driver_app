import 'dart:ui';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════
/// AppToast — إشعارات Toast الموحَّدة
///
/// الاستخدام:
///   AppToast.success('تم قبول الرحلة');
///   AppToast.error('فشل الاتصال بالسيرفر');
///   AppToast.warning('الموقع غير محدَّث');
///   AppToast.info('جاري التحديث...');
///   AppToast.dismiss();
/// ══════════════════════════════════════════════════════════════
class AppToast {
  AppToast._();

  // ─── Success ─────────────────────────────────────────────────
  static void success(String message) => _show(
        message,
        backgroundColor: AppColors.success,
        textColor: AppColors.white,
        gravity: ToastGravity.BOTTOM,
        length: Toast.LENGTH_SHORT,
      );

  // ─── Error ───────────────────────────────────────────────────
  static void error(String message) => _show(
        message,
        backgroundColor: AppColors.error,
        textColor: AppColors.white,
        gravity: ToastGravity.TOP,
        length: Toast.LENGTH_LONG,
      );

  // ─── Warning ─────────────────────────────────────────────────
  static void warning(String message) => _show(
        message,
        backgroundColor: AppColors.warning,
        textColor: AppColors.textInverse,
        gravity: ToastGravity.BOTTOM,
        length: Toast.LENGTH_LONG,
      );

  // ─── Info ────────────────────────────────────────────────────
  static void info(String message) => _show(
        message,
        backgroundColor: AppColors.surfaceElevated,
        textColor: AppColors.textPrimary,
        gravity: ToastGravity.BOTTOM,
        length: Toast.LENGTH_SHORT,
      );

  // ─── Dismiss ─────────────────────────────────────────────────
  static void dismiss() => Fluttertoast.cancel();

  // ─── Internal ────────────────────────────────────────────────
  static void _show(
    String message, {
    required Color backgroundColor,
    required Color textColor,
    required ToastGravity gravity,
    required Toast length,
  }) =>
      Fluttertoast.showToast(
        msg: message,
        backgroundColor: backgroundColor,
        textColor: textColor,
        gravity: gravity,
        toastLength: length,
        fontSize: 14,
      );
}
