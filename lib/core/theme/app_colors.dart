// lib/core/theme/app_colors.dart
import 'package:flutter/material.dart';

class AppColors {
  // ── Dark-mode surface palette ──────────────────────────────────────────────
  static const background     = Color(0xFF070C18); // deepest bg
  static const surface        = Color(0xFF0D1829); // card/surface
  static const surfaceElevated = Color(0xFF142238); // input/chip fill
  static const divider        = Color(0xFF1C2E48); // borders & dividers

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const primary        = Color(0xFF3B82F6); // blue-500
  static const primaryDark    = Color(0xFF2563EB); // blue-600
  static const primarySurface = Color(0xFF0B1A32); // tinted bg behind primary

  // ── Dark-mode text ─────────────────────────────────────────────────────────
  static const textPrimary    = Color(0xFFEEF4FF); // near-white
  static const textSecondary  = Color(0xFF7A9CB8); // muted blue-gray
  static const textDisabled   = Color(0xFF2A3D58); // very muted

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const success = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);
}
