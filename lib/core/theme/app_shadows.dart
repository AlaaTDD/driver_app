import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';

/// نظام الظلال الموحَّد
class AppShadows {
  AppShadows._();

  static final soft = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, 2)),
    BoxShadow(color: AppColors.black.withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
  ];

  static final medium = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4)),
    BoxShadow(color: AppColors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1)),
  ];

  static final strong = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.24), blurRadius: 32, spreadRadius: 0, offset: const Offset(0, -6)),
    BoxShadow(color: AppColors.black.withValues(alpha: 0.08), blurRadius: 8, spreadRadius: 0, offset: const Offset(0, -2)),
  ];

  static final primaryBtn = [
    BoxShadow(color: AppColors.primary.withValues(alpha: 0.38), blurRadius: 18, offset: const Offset(0, 6)),
  ];

  static final success = [
    BoxShadow(color: AppColors.success.withValues(alpha: 0.32), blurRadius: 16, offset: const Offset(0, 5)),
  ];

  static final drawer = [
    BoxShadow(color: AppColors.black.withValues(alpha: 0.40), blurRadius: 48, offset: const Offset(8, 0)),
  ];
}
