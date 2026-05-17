import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';



extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  
  
  Color get bgColor       => AppColors.background;
  Color get cardColor     => AppColors.surface;
  Color get elevatedColor => AppColors.surfaceElevated;
  Color get divColor      => AppColors.divider;

  Color get textPrimary   => AppColors.textPrimary;
  Color get textSecondary => AppColors.textSecondary;
  Color get textDisabled  => AppColors.textDisabled;

  Color get primaryTint   => AppColors.primarySurface;

  
  Color get hBg          => bgColor;
  Color get hSurface     => cardColor;
  Color get hSurfaceEl   => elevatedColor;
  Color get hDivider     => divColor;
  Color get hTextPrimary    => textPrimary;
  Color get hTextSecondary  => textSecondary;
  Color get hPrimaryBg   => primaryTint;

  // alias — same as bgColor; used by wallet screen
  Color get surfaceColor  => bgColor;
}

