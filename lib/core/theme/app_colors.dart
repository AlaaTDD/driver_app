import 'package:flutter/material.dart';


class AppColors {
  // Standard
  static const white           = Colors.white;
  static const black           = Colors.black;
  static const transparent     = Colors.transparent;
  static const grey            = Colors.grey;

  // Background
  static const background      = Color(0xFF070C18);
  static const surface         = Color(0xFF181C2A); // _C.card
  static const surfaceElevated = Color(0xFF1E2336); // _C.elevated
  static const divider         = Color(0xFF252A3D); // _C.border

  // Brand
  static const primary        = Color(0xFF4C8BF5); // _C.blue
  static const primaryDark    = Color(0xFF3868C0); // Darker blue
  static const secondary      = Color(0xFF1FC87A); // _C.emerald
  static const primarySurface = Color(0xFF12151F); // _C.sheet

  // Additional Brand / Accents
  static const purple         = Color(0xFF9333EA);
  static const purpleDark     = Color(0xFF7E22CE);
  static const purpleLight    = Color(0xFFD8B4FE);
  static const indigo         = Color(0xFF4F46E5);
  static const indigoLight    = Color(0xFFA5B4FC);
  static const info           = Color(0xFF3B82F6);
  static const infoLight      = Color(0xFF93C5FD);

  // Text
  static const textPrimary   = Color(0xFFEEF0FF); // _C.t1
  static const textSecondary = Color(0xFF7B82A3); // _C.t2
  static const textDisabled  = Color(0xFF3A4060); // _C.t3

  // Semantic
  static const success       = Color(0xFF1FC87A); // _C.emerald
  static const successLight  = Color(0xFF6EE7B7);
  static const successSurface= Color(0x331FC87A); // 20% opacity
  
  static const warning       = Color(0xFFF5A524); // _C.amber
  static const warningLight  = Color(0xFFFCD34D);
  static const warningSurface= Color(0x33F5A524); // 20% opacity
  
  static const error         = Color(0xFFFF4060); // _C.rose
  static const errorLight    = Color(0xFFFDA4AF);
  static const errorSurface  = Color(0x33FF4060); // 20% opacity

  // Dark Theme specifics
  static const darkBg              = Color(0xFF070C18);
  static const darkSurface         = Color(0xFF181C2A);
  static const darkElevated        = Color(0xFF1E2336);
  static const darkDivider         = Color(0xFF252A3D);
  static const darkSheet           = Color(0xFF12151F);
  static const darkTextPrimary     = Color(0xFFEEF0FF);
  static const darkTextSecondary   = Color(0xFF7B82A3);
  static const darkTextDisabled    = Color(0xFF3A4060);

  // Light Theme specifics
  static const lightBg             = Color(0xFFF8FAFC);
  static const lightSurface        = Color(0xFFFFFFFF);
  static const lightElevated       = Color(0xFFF1F5F9);
  static const lightDivider        = Color(0xFFE2E8F0);
  static const lightSheet          = Color(0xFFFFFFFF);
  static const lightTextPrimary    = Color(0xFF0F172A);
  static const lightTextSecondary  = Color(0xFF64748B);
  static const lightTextDisabled   = Color(0xFF94A3B8);
}
