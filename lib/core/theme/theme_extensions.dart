import 'package:flutter/material.dart';



extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  
  
  Color get bgColor       => const Color(0xFF0D0F18);
  Color get cardColor     => const Color(0xFF181C2A);
  Color get elevatedColor => const Color(0xFF1E2336);
  Color get divColor      => const Color(0xFF252A3D);

  Color get textPrimary   => const Color(0xFFEEF0FF);
  Color get textSecondary => const Color(0xFF7B82A3);
  Color get textDisabled  => const Color(0xFF3A4060);

  Color get primaryTint   => const Color(0xFF12151F);

  
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

