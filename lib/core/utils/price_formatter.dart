import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';

/// فورماتر مركزي لعرض الأسعار والأرباح في كل أنحاء التطبيق.
///
/// **لماذا؟**
/// قبل هذا الفورماتر كانت كل شاشة تستخدم طريقة مختلفة:
/// - `toStringAsFixed(0)` → تقريب خاطئ (11.50 → "12")
/// - `toStringAsFixed(2)` → دقيقة بس مفيش تحكم
/// - `price.toString()` → raw double بدون تنسيق
/// - `NumberFormat.currency(decimalDigits: 2)` → جيدة بس مش موحدة
///
/// **الاستخدام:**
/// ```dart
/// // عرض ذكي: لو فيه سنتات يعرضها، لو مش هيشيلها
/// PriceFormatter.display(context, 11.50)    → "11.50"
/// PriceFormatter.display(context, 125.00)   → "125"
///
/// // عرض ثابت بـ 2 خانات دايماً
/// PriceFormatter.displayFixed(context, 11.50) → "11.50"
///
/// // عرض مختصر بدون سنتات — للإجماليات والأرقام الكبيرة
/// PriceFormatter.displayCompact(context, 125.50) → "126" (مقرب للرقم الأقرب)
/// ```
class PriceFormatter {
  PriceFormatter._();

  /// عرض ذكي: لو القيمة فيها سنتات حقيقية → خانتين عشريتين.
  /// لو مفيش سنتات → من غير decimals.
  ///
  /// أمثلة:
  /// - `11.50` → `"11.50"`
  /// - `125.00` → `"125"`
  /// - `0.75` → `"0.75"`
  /// - `0.00` → `"0"`
  static String display(BuildContext context, double amount) {
    if (amount == amount.truncateToDouble()) {
      return _compactFormat(context, amount);
    }
    return _fixedFormat(context, amount);
  }

  /// عرض ثابت بـ 2 خانتين عشريتين دايماً.
  ///
  /// أمثلة:
  /// - `11.50` → `"11.50"`
  /// - `125.00` → `"125.00"`
  /// - `0.75` → `"0.75"`
  static String displayFixed(BuildContext context, double amount) {
    return _fixedFormat(context, amount);
  }

  /// عرض مختصر بدون سنتات — للإجماليات الكبيرة.
  /// بيقرب لأقرب رقم صحيح.
  ///
  /// أمثلة:
  /// - `125.50` → `"126"`
  /// - `125.00` → `"125"`
  static String displayCompact(BuildContext context, double amount) {
    return _compactFormat(context, amount);
  }

  /// عرض ذكي مع رمز العملة (مثل `"11.50 ر.س"` أو `"125 SAR"`).
  static String displayWithCurrency(BuildContext context, double amount) {
    final price = display(context, amount);
    final currency = AppLocalizations.of(context)!.currencySar;
    return AppLocalizations.of(context)!.priceWithCurrency(price, currency);
  }

  /// عرض ثابت مع رمز العملة.
  static String displayFixedWithCurrency(BuildContext context, double amount) {
    final price = displayFixed(context, amount);
    final currency = AppLocalizations.of(context)!.currencySar;
    return AppLocalizations.of(context)!.priceWithCurrency(price, currency);
  }

  /// عرض مختصر مع رمز العملة.
  static String displayCompactWithCurrency(
      BuildContext context, double amount) {
    final price = displayCompact(context, amount);
    final currency = AppLocalizations.of(context)!.currencySar;
    return AppLocalizations.of(context)!.priceWithCurrency(price, currency);
  }

  // ── Formatters الداخلية ──────────────────────────────────────────────────

  static NumberFormat _fixedFormatInstance(String locale, String symbol) {
    return NumberFormat.currency(
      locale: locale,
      symbol: '',
      decimalDigits: 2,
    );
  }

  static NumberFormat _compactFormatInstance(String locale, String symbol) {
    return NumberFormat.currency(
      locale: locale,
      symbol: '',
      decimalDigits: 0,
    );
  }

  static String _fixedFormat(BuildContext context, double amount) {
    final locale = Localizations.localeOf(context).languageCode;
    return _fixedFormatInstance(locale, '').format(amount);
  }

  static String _compactFormat(BuildContext context, double amount) {
    final locale = Localizations.localeOf(context).languageCode;
    return _compactFormatInstance(locale, '').format(amount);
  }
}
