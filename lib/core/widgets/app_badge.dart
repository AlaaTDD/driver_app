import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_radius.dart';
import 'package:snapix/core/theme/app_spacing.dart';

enum AppBadgeVariant { primary, success, warning, error, info, neutral }

class AppBadge extends StatelessWidget {
  final String label;
  final AppBadgeVariant variant;
  final bool dot;

  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.dot = false,
  });

  (Color, Color) get _colors => switch (variant) {
        AppBadgeVariant.primary => (
            AppColors.primarySurface,
            AppColors.primary
          ),
        AppBadgeVariant.success => (
            AppColors.successSurface,
            AppColors.success
          ),
        AppBadgeVariant.warning => (
            AppColors.warningSurface,
            AppColors.warning
          ),
        AppBadgeVariant.error => (AppColors.errorSurface, AppColors.error),
        AppBadgeVariant.info => (AppColors.primarySurface, AppColors.info),
        AppBadgeVariant.neutral => (
            AppColors.darkElevated,
            AppColors.darkTextSecondary
          ),
      };

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colors;
    return Container(
      padding: AppSpacing.chip,
      decoration: BoxDecoration(color: bg, borderRadius: AppRadius.xs_),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
