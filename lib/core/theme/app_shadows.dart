import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// ══════════════════════════════════════════════════════════════
/// AppShadows — نظام الظلال الموحَّد
///
/// الاستخدام:
///   boxShadow: AppShadows.soft     ← ظل خفيف للكروت
///   boxShadow: AppShadows.medium   ← ظل متوسط لـ modals
///   boxShadow: AppShadows.primaryBtn ← ظل أزرق للأزرار الرئيسية
/// ══════════════════════════════════════════════════════════════
class AppShadows {
  AppShadows._();

  // ─── Elevation shadows ───────────────────────────────────────
  /// ظل خفيف جداً — للكروت الهادئة
  static final soft = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 8,  offset: const Offset(0, 2)),
    BoxShadow(color: AppColors.black.withValues(alpha: 0.04), blurRadius: 2,  offset: const Offset(0, 1)),
  ];

  /// ظل متوسط — للـ dialogs وكروت البطاقة
  static final medium = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4)),
    BoxShadow(color: AppColors.black.withValues(alpha: 0.06), blurRadius: 3,  offset: const Offset(0, 1)),
  ];

  /// ظل قوي — للـ Bottom Sheets والـ Drawers
  static final strong = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.28), blurRadius: 32, offset: const Offset(0, -6)),
    BoxShadow(color: AppColors.black.withValues(alpha: 0.10), blurRadius: 8,  offset: const Offset(0, -2)),
  ];

  // ─── Brand color shadows ──────────────────────────────────────
  /// ظل أزرق — لأزرار Primary عند حالة الـ active
  static final primaryBtn = [
    BoxShadow(color: AppColors.primary.withValues(alpha: 0.38), blurRadius: 18, offset: const Offset(0, 6)),
  ];

  /// ظل أخضر — لأزرار Success/Secondary
  static final success = [
    BoxShadow(color: AppColors.success.withValues(alpha: 0.32), blurRadius: 16, offset: const Offset(0, 5)),
  ];

  /// ظل أحمر — لأزرار الخطر أو التنبيهات
  static final danger = [
    BoxShadow(color: AppColors.error.withValues(alpha: 0.28), blurRadius: 16, offset: const Offset(0, 5)),
  ];

  // ─── Component-specific ──────────────────────────────────────
  /// ظل جانبي للـ Drawer
  static final drawer = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.40), blurRadius: 48, offset: const Offset(8, 0)),
  ];

  /// ظل للـ Map overlays والـ FABs
  static final mapButton = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 4)),
    BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 3,  offset: const Offset(0, 1)),
  ];

  /// ظل بدون لون للمسح (disabled state)
  static const List<BoxShadow> none = [];
}
