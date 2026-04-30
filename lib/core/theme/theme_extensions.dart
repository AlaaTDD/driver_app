import 'package:flutter/material.dart';

/// Global theme-aware color extension. Use context.bgColor, context.cardColor, etc.
/// h-prefixed aliases are provided for backwards compatibility.
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  // ── Backgrounds ─────────────────────────────────────────────────────────
  /// Deepest scaffold background
  Color get bgColor       => isDark ? const Color(0xFF070C18) : const Color(0xFFF2F6FC);
  /// Card / sheet surface
  Color get cardColor     => isDark ? const Color(0xFF0D1829) : const Color(0xFFFFFFFF);
  /// Input fill, chip fill, elevated items
  Color get elevatedColor => isDark ? const Color(0xFF142238) : const Color(0xFFE8F0FA);

  // ── Borders ──────────────────────────────────────────────────────────────
  Color get divColor => isDark ? const Color(0xFF1C2E48) : const Color(0xFFD4E0EF);

  // ── Text ─────────────────────────────────────────────────────────────────
  Color get textPrimary    => isDark ? const Color(0xFFEEF4FF) : const Color(0xFF09172A);
  Color get textSecondary  => isDark ? const Color(0xFF7A9CB8) : const Color(0xFF506070);
  Color get textDisabled   => isDark ? const Color(0xFF2A3D58) : const Color(0xFFAAB8C8);

  // ── Tints ────────────────────────────────────────────────────────────────
  /// Light primary-tinted background for badges / chips
  Color get primaryTint => isDark ? const Color(0xFF0B1A32) : const Color(0xFFEAF2FF);

  // ── h-aliases (backwards compat) ─────────────────────────────────────────
  Color get hBg          => bgColor;
  Color get hSurface     => cardColor;
  Color get hSurfaceEl   => elevatedColor;
  Color get hDivider     => divColor;
  Color get hTextPrimary    => textPrimary;
  Color get hTextSecondary  => textSecondary;
  Color get hPrimaryBg   => primaryTint;
}
