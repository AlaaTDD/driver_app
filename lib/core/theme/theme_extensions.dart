import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'app_spacing.dart';
import 'app_radius.dart';

/// ══════════════════════════════════════════════════════════════
/// AppThemeX — امتدادات BuildContext الأساسية
///
/// استخدام:
///   context.bgColor           ← خلفية الشاشة
///   context.textPrimary       ← لون النص الرئيسي
///   context.ts.titleMd        ← TextStyle + اللون التلقائي
///   context.sp.lg             ← 16.0
///   context.r.xl_             ← BorderRadius.circular(16)
/// ══════════════════════════════════════════════════════════════
extension AppThemeX on BuildContext {
  // ─── Theme state ─────────────────────────────────────────────
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  ThemeData get theme => Theme.of(this);

  // ─── Shortcuts ───────────────────────────────────────────────
  /// نظام الـ TextStyles — مثال: context.ts.titleMd.colored(context.textPrimary)
  _TextStylesProxy get ts => const _TextStylesProxy();
  /// نظام المسافات — مثال: SizedBox(height: context.sp.lg)
  _SpacingProxy get sp => const _SpacingProxy();
  /// نظام الـ BorderRadius — مثال: borderRadius: context.r.xl_
  _RadiusProxy get r => const _RadiusProxy();

  // ─── Backgrounds ─────────────────────────────────────────────
  Color get bgColor        => isDark ? AppColors.background     : AppColors.lightBg;
  Color get cardColor      => isDark ? AppColors.surface        : AppColors.lightSurface;
  Color get elevatedColor  => isDark ? AppColors.surfaceElevated : AppColors.lightElevated;
  Color get divColor       => isDark ? AppColors.divider        : AppColors.lightDivider;
  Color get sheetColor     => isDark ? AppColors.primarySurface : AppColors.lightSheet;
  Color get overlayColor   => isDark ? AppColors.overlay        : AppColors.lightOverlay;

  // ─── Text ─────────────────────────────────────────────────────
  Color get textPrimary    => isDark ? AppColors.textPrimary    : AppColors.lightTextPrimary;
  Color get textSecondary  => isDark ? AppColors.textSecondary  : AppColors.lightTextSecondary;
  Color get textDisabled   => isDark ? AppColors.textDisabled   : AppColors.lightTextDisabled;
  Color get textInverse    => isDark ? AppColors.textInverse    : AppColors.textPrimary;

  // ─── Brand (ثابتة — لا تتغير مع الثيم) ──────────────────────
  Color get primaryColor   => AppColors.primary;
  Color get secondaryColor => AppColors.secondary;

  // ─── Semantic ─────────────────────────────────────────────────
  Color get successColor   => AppColors.success;
  Color get warningColor   => AppColors.warning;
  Color get errorColor     => AppColors.error;
  Color get infoColor      => AppColors.info;

  // ─── Semantic surfaces (شفافة) ───────────────────────────────
  Color get successSurface => AppColors.successSurface;
  Color get warningSurface => AppColors.warningSurface;
  Color get errorSurface   => AppColors.errorSurface;
  Color get infoSurface    => AppColors.infoSurface;

  // ─── Backward-compat aliases (لا تضف جديداً هنا) ────────────
  Color get primaryTint   => sheetColor;
  Color get surfaceColor  => bgColor;
  Color get hBg           => bgColor;
  Color get hSurface      => cardColor;
  Color get hSurfaceEl    => elevatedColor;
  Color get hDivider      => divColor;
  Color get hTextPrimary  => textPrimary;
  Color get hTextSecondary => textSecondary;
  Color get hPrimaryBg    => primaryTint;
}

// ─── Internal proxy: لا تستخدمها مباشرة ─────────────────────
class _TextStylesProxy {
  const _TextStylesProxy();
  TextStyle get displayLg  => AppTextStyles.displayLg;
  TextStyle get displayMd  => AppTextStyles.displayMd;
  TextStyle get displaySm  => AppTextStyles.displaySm;
  TextStyle get headlineLg => AppTextStyles.headlineLg;
  TextStyle get headlineMd => AppTextStyles.headlineMd;
  TextStyle get headlineSm => AppTextStyles.headlineSm;
  TextStyle get titleLg    => AppTextStyles.titleLg;
  TextStyle get titleMd    => AppTextStyles.titleMd;
  TextStyle get titleSm    => AppTextStyles.titleSm;
  TextStyle get bodyLg     => AppTextStyles.bodyLg;
  TextStyle get bodyMd     => AppTextStyles.bodyMd;
  TextStyle get bodySm     => AppTextStyles.bodySm;
  TextStyle get labelLg    => AppTextStyles.labelLg;
  TextStyle get labelMd    => AppTextStyles.labelMd;
  TextStyle get labelSm    => AppTextStyles.labelSm;
  TextStyle get labelXs    => AppTextStyles.labelXs;
  TextStyle get captionMd  => AppTextStyles.captionMd;
  TextStyle get captionSm  => AppTextStyles.captionSm;
  TextStyle get priceLg    => AppTextStyles.priceLg;
  TextStyle get priceMd    => AppTextStyles.priceMd;
  TextStyle get priceSm    => AppTextStyles.priceSm;
}

class _SpacingProxy {
  const _SpacingProxy();
  double get xs => AppSpacing.xs;
  double get sm => AppSpacing.sm;
  double get md => AppSpacing.md;
  double get lg => AppSpacing.lg;
  double get xl => AppSpacing.xl;
  double get xxl => AppSpacing.xxl;
  double get xxxl => AppSpacing.xxxl;
  double get huge => AppSpacing.huge;
}

class _RadiusProxy {
  const _RadiusProxy();
  BorderRadius get xs_ => AppRadius.xs_;
  BorderRadius get sm_ => AppRadius.sm_;
  BorderRadius get md_ => AppRadius.md_;
  BorderRadius get lg_ => AppRadius.lg_;
  BorderRadius get xl_ => AppRadius.xl_;
  BorderRadius get xxl_ => AppRadius.xxl_;
  BorderRadius get xxxl_ => AppRadius.xxxl_;
  BorderRadius get huge_ => AppRadius.huge_;
  BorderRadius get full_ => AppRadius.full_;
  BorderRadius get sheetTop => AppRadius.sheetTop;
  BorderRadius get sheetTopXl => AppRadius.sheetTopXl;
  BorderRadius get cardBottom => AppRadius.cardBottom;
  BorderRadius get cardTop => AppRadius.cardTop;
}

/// ══════════════════════════════════════════════════════════════
/// TextStyle extensions
/// ══════════════════════════════════════════════════════════════
extension TextStyleX on TextStyle {
  /// تطبيق لون على الـ style: Text('...', style: context.ts.titleMd.colored(context.textPrimary))
  TextStyle colored(Color color) => copyWith(color: color);

  /// تطبيق وزن مختلف بسرعة
  TextStyle get bold    => copyWith(fontWeight: FontWeight.w700);
  TextStyle get medium  => copyWith(fontWeight: FontWeight.w500);
  TextStyle get regular => copyWith(fontWeight: FontWeight.w400);

  /// تطبيق opacity على اللون الحالي
  TextStyle withOpacity(double opacity) =>
      copyWith(color: (color ?? AppColors.textPrimary).withValues(alpha: opacity));
}

/// ══════════════════════════════════════════════════════════════
/// Color extensions
/// ══════════════════════════════════════════════════════════════
extension ColorX on Color {
  /// إنشاء surface بنسبة opacity محددة (بديل withOpacity القديم)
  Color surface([double opacity = 0.15]) => withValues(alpha: opacity);

  /// هل اللون فاتح بما يكفي لاستخدام نص أسود عليه؟
  bool get isLight => computeLuminance() > 0.5;

  /// اللون المناسب للنص فوق هذا اللون
  Color get onColor => isLight ? AppColors.textInverse : AppColors.white;
}
