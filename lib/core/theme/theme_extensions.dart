import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';

extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ألوان الخلفية (تتكيف مع الـ Theme)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  Color get bgColor => isDark ? AppColors.darkBg : AppColors.lightBg;
  Color get cardColor =>
      isDark ? AppColors.darkSurface : AppColors.lightSurface;
  Color get elevatedColor =>
      isDark ? AppColors.darkElevated : AppColors.lightElevated;
  Color get divColor => isDark ? AppColors.darkDivider : AppColors.lightDivider;
  Color get sheetColor => isDark ? AppColors.darkSheet : AppColors.lightSheet;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // ألوان النص (تتكيف)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  Color get textPrimary =>
      isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
  Color get textSecondary =>
      isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
  Color get textDisabled =>
      isDark ? AppColors.darkTextDisabled : AppColors.lightTextDisabled;

  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  // Aliases للتوافق مع الكود القديم (لا تحذفها)
  // ━━━━━━━━━━━━━━━━━━━━━━━━━━
  Color get primaryTint => sheetColor;
  Color get surfaceColor => bgColor;
  Color get hBg => bgColor;
  Color get hSurface => cardColor;
  Color get hSurfaceEl => elevatedColor;
  Color get hDivider => divColor;
  Color get hTextPrimary => textPrimary;
  Color get hTextSecondary => textSecondary;
  Color get hPrimaryBg => primaryTint;
}
