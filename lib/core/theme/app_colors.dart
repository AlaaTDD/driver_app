import 'package:flutter/material.dart';

/// ══════════════════════════════════════════════════════════════
/// AppColors — نظام الألوان الموحَّد للتطبيق
///
/// الاستخدام الصحيح دائماً من خلال BuildContext extensions:
///   context.bgColor       ← يتكيف مع Dark/Light تلقائياً
///   context.textPrimary   ← يتكيف مع Dark/Light تلقائياً
///
/// الاستخدام المباشر (للثوابت فقط — لا يتكيف مع الثيم):
///   AppColors.primary     ← أزرق العلامة التجارية
///   AppColors.error       ← أحمر الخطأ
/// ══════════════════════════════════════════════════════════════
class AppColors {
  AppColors._();

  // ─── Neutral ─────────────────────────────────────────────────
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const transparent = Colors.transparent;

  // ─── Dark Theme — Backgrounds ────────────────────────────────
  /// الخلفية الرئيسية للشاشة (أعمق طبقة)
  static const background     = Color(0xFF070C18);
  /// بطاقات / Containers فوق الخلفية
  static const surface        = Color(0xFF181C2A);
  /// عناصر مرفوعة فوق السطح (inputs, chips)
  static const surfaceElevated = Color(0xFF1E2336);
  /// فواصل وحدود خفيفة
  static const divider        = Color(0xFF252A3D);
  /// خلفية Bottom Sheets والـ drawers
  static const primarySurface = Color(0xFF12151F);
  /// overlay شفافة فوق الخريطة أو الخلفية
  static const overlay        = Color(0xB3070C18); // 70% opacity

  // ─── Dark Theme — Text ───────────────────────────────────────
  static const textPrimary    = Color(0xFFEEF0FF);
  static const textSecondary  = Color(0xFF7B82A3);
  static const textDisabled   = Color(0xFF3A4060);
  static const textInverse    = Color(0xFF0F172A); // على خلفيات فاتحة

  // ─── Light Theme — Backgrounds ───────────────────────────────
  static const lightBg           = Color(0xFFF8FAFC);
  static const lightSurface      = Color(0xFFFFFFFF);
  static const lightElevated     = Color(0xFFF1F5F9);
  static const lightDivider      = Color(0xFFE2E8F0);
  static const lightSheet        = Color(0xFFFFFFFF);
  static const lightOverlay      = Color(0xB3F8FAFC); // 70% opacity

  // ─── Light Theme — Text ──────────────────────────────────────
  static const lightTextPrimary   = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF64748B);
  static const lightTextDisabled  = Color(0xFF94A3B8);

  // ─── Brand ───────────────────────────────────────────────────
  /// الأزرق الرئيسي للعلامة التجارية
  static const primary        = Color(0xFF4C8BF5);
  static const primaryDark    = Color(0xFF3868C0);
  static const primaryLight   = Color(0xFF93C5FD);
  /// سطح أزرق شفاف للـ badges والـ chips
  static const primarySurface20 = Color(0x334C8BF5); // 20% opacity

  /// الأخضر الثانوي (قبول / نشاط / ناجح)
  static const secondary      = Color(0xFF1FC87A);
  static const secondaryDark  = Color(0xFF15955B);
  static const secondaryLight = Color(0xFF6EE7B7);

  // ─── Semantic — Success ──────────────────────────────────────
  static const success        = Color(0xFF1FC87A);
  static const successLight   = Color(0xFF6EE7B7);
  static const successSurface = Color(0x331FC87A); // 20%

  // ─── Semantic — Warning ──────────────────────────────────────
  static const warning        = Color(0xFFF5A524);
  static const warningLight   = Color(0xFFFCD34D);
  static const warningSurface = Color(0x33F5A524); // 20%

  // ─── Semantic — Error ────────────────────────────────────────
  static const error          = Color(0xFFFF4060);
  static const errorLight     = Color(0xFFFDA4AF);
  static const errorSurface   = Color(0x33FF4060); // 20%

  // ─── Semantic — Info ─────────────────────────────────────────
  static const info           = Color(0xFF3B82F6);
  static const infoLight      = Color(0xFF93C5FD);
  static const infoSurface    = Color(0x333B82F6); // 20%

  // ─── Accents ─────────────────────────────────────────────────
  static const purple         = Color(0xFF9333EA);
  static const purpleDark     = Color(0xFF7E22CE);
  static const purpleLight    = Color(0xFFD8B4FE);
  static const purpleSurface  = Color(0x339333EA); // 20%

  static const indigo         = Color(0xFF4F46E5);
  static const indigoLight    = Color(0xFFA5B4FC);

  // ─── Gradient helpers ────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [background, surface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Taxi-domain — Driver Status ───────────────────────────
  /// أخضر داكن — خلفية بطاقة "السائق متصل"
  static const onlineBg       = Color(0xFF0F2D1A);
  /// رمادي داكن — خلفية بطاقة "غير متصل"
  static const offlineBg      = Color(0xFF1A1D28);
  /// لون نص "متصل" + indicator
  static const onlineGreen    = Color(0xFF22C55E);
  static const onlineSurface  = Color(0x3322C55E); // 20%
  /// لون نص "غير متصل" + indicator
  static const offlineGray    = Color(0xFF64748B);
  static const offlineSurface = Color(0x3364748B); // 20%

  // ─── Taxi-domain — Trip Lifecycle ───────────────────────
  /// لون "بحث عن سائق" (برتقالي)
  static const searching      = Color(0xFFF5A524);
  static const searchingSurface = Color(0x33F5A524);
  /// لون "تم القبول" (أزرق فاتح)
  static const accepted       = Color(0xFF3B9EFF);
  static const acceptedSurface = Color(0x333B9EFF);
  /// لون "في الطريق" (secondary أخضر)
  static const inProgress     = Color(0xFF1FC87A);
  static const inProgressSurface = Color(0x331FC87A);

  // ─── Taxi-domain — Earnings ────────────────────────────
  /// لون الأرباح — أخضر ذهبي
  static const earningsGold   = Color(0xFFEAB308);
  static const earningsGoldSurface = Color(0x33EAB308);
  /// خلفية لوحة الأرباح (dark)
  static const earningsBg     = Color(0xFF0D2B1D);

  // ─── Map ─────────────────────────────────────────
  /// scrim فوق الخريطة (شفاف جداً)
  static const mapScrim       = Color(0x99070C18); // 60% opacity
  /// لون المسار بين نقطتين
  static const routeBlue      = Color(0xFF4C8BF5);
  static const routeDashed    = Color(0xFF7B82A3); // الجزء غير المقطوع
  /// ماركر نقطة الالتقاء (أصفر زاه)
  static const pickupPin      = Color(0xFFF5A524);
  /// ماركر الوجهة
  static const destinationPin = Color(0xFFFF4060);

  @Deprecated('Use AppColors.background')      static const darkBg = background;
  @Deprecated('Use AppColors.surface')         static const darkSurface = surface;
  @Deprecated('Use AppColors.surfaceElevated') static const darkElevated = surfaceElevated;
  @Deprecated('Use AppColors.divider')         static const darkDivider = divider;
  @Deprecated('Use AppColors.primarySurface')  static const darkSheet = primarySurface;
  @Deprecated('Use AppColors.textPrimary')     static const darkTextPrimary = textPrimary;
  @Deprecated('Use AppColors.textSecondary')   static const darkTextSecondary = textSecondary;
  @Deprecated('Use AppColors.textDisabled')    static const darkTextDisabled = textDisabled;
  @Deprecated('Use AppColors.grey (Colors.grey)') static const grey = Colors.grey;
}
