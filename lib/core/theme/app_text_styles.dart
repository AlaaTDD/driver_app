import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// نظام الطباعة الموحَّد لـ Snapix
class AppTextStyles {
  AppTextStyles._();

  static const displayLg = TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.5);
  static const displayMd = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.2,
      letterSpacing: -0.4);
  static const displaySm = TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      height: 1.3,
      letterSpacing: -0.3);

  static const headlineLg =
      TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3);
  static const headlineMd =
      TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3);
  static const headlineSm =
      TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.4);

  static const titleLg =
      TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.4);
  static const titleMd =
      TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4);
  static const titleSm =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.4);

  static const bodyLg =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.6);
  static const bodyMd =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.6);
  static const bodySm =
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.6);

  static const labelLg =
      TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2);
  static const labelMd =
      TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.2);
  static const labelSm =
      TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2);
  static const labelXs =
      TextStyle(fontSize: 11, fontWeight: FontWeight.w500, height: 1.2);

  static const captionMd = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.4,
      letterSpacing: 0.2);
  static const captionSm = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w400,
      height: 1.4,
      letterSpacing: 0.1);

  static const priceLg = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      height: 1.1,
      letterSpacing: -0.5,
      fontFeatures: [FontFeature.tabularFigures()]);
  static const priceMd = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      height: 1.1,
      letterSpacing: -0.3,
      fontFeatures: [FontFeature.tabularFigures()]);
  static const priceSm = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.1,
      fontFeatures: [FontFeature.tabularFigures()]);
}
