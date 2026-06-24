import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// AppSpacing — نظام المسافات الموحَّد
///
/// المقاييس: xs=4 · sm=8 · md=12 · lg=16 · xl=20 · xxl=24 · xxxl=32 · huge=48
///
/// الاستخدام:
///   SizedBox(height: AppSpacing.lg)
///   Padding(padding: AppSpacing.card)
///   AppSpacing.vSm   ← SizedBox(height: 8) جاهز
///   AppSpacing.hLg   ← SizedBox(width: 16) جاهز
/// ══════════════════════════════════════════════════════════════
class AppSpacing {
  const AppSpacing._();

  // ─── Tokens ──────────────────────────────────────────────────
  static const double xs   =  4.0;
  static const double sm   =  8.0;
  static const double md   = 12.0;
  static const double lg   = 16.0;
  static const double xl   = 20.0;
  static const double xxl  = 24.0;
  static const double xxxl = 32.0;
  static const double huge = 48.0;

  // ─── EdgeInsets presets ──────────────────────────────────────
  /// Padding أفقي للشاشة
  static const EdgeInsets screenH = EdgeInsets.symmetric(horizontal: xl);
  /// Padding كامل للشاشة
  static const EdgeInsets screen  = EdgeInsets.fromLTRB(xl, lg, xl, xxxl);
  /// Padding داخلي للكروت
  static const EdgeInsets card    = EdgeInsets.all(lg);
  static const EdgeInsets cardLg  = EdgeInsets.all(xl);
  /// Padding داخلي للـ Bottom Sheets
  static const EdgeInsets sheet   = EdgeInsets.fromLTRB(xl, lg, xl, 34);
  /// Padding للـ chips الصغيرة
  static const EdgeInsets chip    = EdgeInsets.symmetric(horizontal: md, vertical: xs);
  /// Padding للأزرار الصغيرة
  static const EdgeInsets btnSm   = EdgeInsets.symmetric(horizontal: lg, vertical: sm);
  /// Padding للأزرار المتوسطة
  static const EdgeInsets btnMd   = EdgeInsets.symmetric(horizontal: xl, vertical: md);
  /// Padding للأزرار الكبيرة
  static const EdgeInsets btnLg   = EdgeInsets.symmetric(horizontal: xxl, vertical: 15);
  /// Padding للـ list tiles
  static const EdgeInsets listTile = EdgeInsets.symmetric(horizontal: lg, vertical: md);
  /// Padding للحقول
  static const EdgeInsets inputV  = EdgeInsets.symmetric(horizontal: lg, vertical: md);

  // ─── SizedBox shortcuts ──────────────────────────────────────
  static const Widget vXs   = SizedBox(height: xs);
  static const Widget vSm   = SizedBox(height: sm);
  static const Widget vMd   = SizedBox(height: md);
  static const Widget vLg   = SizedBox(height: lg);
  static const Widget vXl   = SizedBox(height: xl);
  static const Widget vXxl  = SizedBox(height: xxl);
  static const Widget vXxxl = SizedBox(height: xxxl);
  static const Widget vHuge = SizedBox(height: huge);

  static const Widget hXs   = SizedBox(width: xs);
  static const Widget hSm   = SizedBox(width: sm);
  static const Widget hMd   = SizedBox(width: md);
  static const Widget hLg   = SizedBox(width: lg);
  static const Widget hXl   = SizedBox(width: xl);
  static const Widget hXxl  = SizedBox(width: xxl);

  /// فاصل مرن في الـ Rows/Columns
  static const Widget expand = Spacer();
}
