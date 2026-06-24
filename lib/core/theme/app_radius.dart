import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// AppRadius — نظام الزوايا الموحَّد
///
/// الاستخدام:
///   borderRadius: AppRadius.xl_         ← BorderRadius.circular(16)
///   borderRadius: AppRadius.sheetTop    ← فقط الزوايا العلوية
///
/// عبر context (بعد import theme_extensions):
///   borderRadius: context.r.xl_
/// ══════════════════════════════════════════════════════════════
class AppRadius {
  const AppRadius._();

  // ─── Tokens ──────────────────────────────────────────────────
  static const double xs   =  6.0;
  static const double sm   =  8.0;
  static const double md   = 12.0;
  static const double lg   = 14.0;
  static const double xl   = 16.0;
  static const double xxl  = 20.0;
  static const double xxxl = 24.0;
  static const double huge = 32.0;
  /// دائري تماماً (للأزرار الكاملة الاستدارة والـ chips)
  static const double full = 100.0;

  // ─── BorderRadius presets ────────────────────────────────────
  static final xs_   = BorderRadius.circular(xs);
  static final sm_   = BorderRadius.circular(sm);
  static final md_   = BorderRadius.circular(md);
  static final lg_   = BorderRadius.circular(lg);
  static final xl_   = BorderRadius.circular(xl);
  static final xxl_  = BorderRadius.circular(xxl);
  static final xxxl_ = BorderRadius.circular(xxxl);
  static final huge_ = BorderRadius.circular(huge);
  static final full_ = BorderRadius.circular(full);

  // ─── Special shapes ──────────────────────────────────────────
  /// Bottom Sheet — زوايا علوية فقط (xxxl)
  static final sheetTop = const BorderRadius.vertical(top: Radius.circular(xxxl));
  /// Bottom Sheet كبير — زوايا علوية huge
  static final sheetTopXl = const BorderRadius.vertical(top: Radius.circular(huge));
  /// Card مع زاوية سفلية حادة (مثل tooltips)
  static final cardBottom = const BorderRadius.vertical(bottom: Radius.circular(xl));
  /// زوايا علوية فقط للكروت المتداخلة
  static final cardTop = const BorderRadius.vertical(top: Radius.circular(xl));

  // ─── Helper ──────────────────────────────────────────────────
  /// إنشاء BorderRadius مخصصة بسرعة
  static BorderRadius only({
    double topLeft   = 0,
    double topRight  = 0,
    double bottomLeft  = 0,
    double bottomRight = 0,
  }) => BorderRadius.only(
    topLeft:     Radius.circular(topLeft),
    topRight:    Radius.circular(topRight),
    bottomLeft:  Radius.circular(bottomLeft),
    bottomRight: Radius.circular(bottomRight),
  );
}
