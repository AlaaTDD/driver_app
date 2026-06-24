import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// AppTextStyles — نظام الطباعة الموحَّد
///
/// التسلسل الهرمي:
///   display   → عناوين بطولية (32–24 px) — Hero sections
///   headline  → عناوين الشاشات (22–18 px)
///   title     → عناوين الكروت والأقسام (17–13 px)
///   body      → النصوص العادية (16–13 px)
///   label     → الأزرار والشارات (16–11 px)
///   caption   → النصوص الثانوية الصغيرة (12–11 px)
///   price     → عرض الأسعار بـ tabular figures (28–16 px)
///
/// الاستخدام:
///   Text('عنوان', style: AppTextStyles.headlineMd)
///   Text('نص', style: AppTextStyles.bodyMd.colored(context.textSecondary))
/// ══════════════════════════════════════════════════════════════
class AppTextStyles {
  AppTextStyles._();

  // ─── Display ─────────────────────────────────────────────────
  static const displayLg = TextStyle(
    fontSize: 32, fontWeight: FontWeight.w800,
    height: 1.2, letterSpacing: -0.5,
  );
  static const displayMd = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w800,
    height: 1.2, letterSpacing: -0.4,
  );
  static const displaySm = TextStyle(
    fontSize: 24, fontWeight: FontWeight.w700,
    height: 1.3, letterSpacing: -0.3,
  );

  // ─── Headline ─────────────────────────────────────────────────
  static const headlineLg = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static const headlineMd = TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3);
  static const headlineSm = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4);

  // ─── Title ────────────────────────────────────────────────────
  static const titleLg = TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4);
  static const titleMd = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);
  static const titleSm = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4);

  // ─── Body ─────────────────────────────────────────────────────
  static const bodyLg = TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6);
  static const bodyMd = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6);
  static const bodySm = TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.6);

  // ─── Label ────────────────────────────────────────────────────
  static const labelLg = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2);
  static const labelMd = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2);
  static const labelSm = TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2);
  static const labelXs = TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.2);

  // ─── Caption ──────────────────────────────────────────────────
  static const captionMd = TextStyle(
    fontSize: 12, fontWeight: FontWeight.w400,
    height: 1.4, letterSpacing: 0.2,
  );
  static const captionSm = TextStyle(
    fontSize: 11, fontWeight: FontWeight.w400,
    height: 1.4, letterSpacing: 0.1,
  );

  // ─── Price ────────────────────────────────────────────────────
  static const priceLg = TextStyle(
    fontSize: 28, fontWeight: FontWeight.w800,
    height: 1.1, letterSpacing: -0.5,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const priceMd = TextStyle(
    fontSize: 20, fontWeight: FontWeight.w700,
    height: 1.1, letterSpacing: -0.3,
    fontFeatures: [FontFeature.tabularFigures()],
  );
  static const priceSm = TextStyle(
    fontSize: 16, fontWeight: FontWeight.w600,
    height: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

/// امتداد مساعد لتلوين أي TextStyle بسهولة
extension AppTextStyleX on TextStyle {
  TextStyle colored(Color color) => copyWith(color: color);
  TextStyle get semibold => copyWith(fontWeight: FontWeight.w600);
  TextStyle get bold     => copyWith(fontWeight: FontWeight.w700);
  TextStyle get extrabold => copyWith(fontWeight: FontWeight.w800);
  TextStyle get regular  => copyWith(fontWeight: FontWeight.w400);
  TextStyle sized(double size) => copyWith(fontSize: size);
}
