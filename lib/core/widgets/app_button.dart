import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_radius.dart';
import 'package:snapix/core/theme/app_shadows.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

enum AppButtonVariant { primary, secondary, outlined, ghost, danger }
enum AppButtonSize { sm, md, lg }

class AppButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.lg,
    this.leadingIcon,
    this.trailingIcon,
  });

  double get _height => switch (size) {
    AppButtonSize.sm => 40,
    AppButtonSize.md => 48,
    AppButtonSize.lg => 54,
  };

  double get _fontSize => switch (size) {
    AppButtonSize.sm => 13,
    AppButtonSize.md => 15,
    AppButtonSize.lg => 16,
  };

  @override
  Widget build(BuildContext context) {
    final bool inactive = isLoading || isDisabled;

    final (bg, fg, gradient, shadows) = switch (variant) {
      AppButtonVariant.primary   => (AppColors.primary, AppColors.white,
          inactive ? null : const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark], begin: Alignment.centerLeft, end: Alignment.centerRight),
          inactive ? <BoxShadow>[] : AppShadows.primaryBtn),
      AppButtonVariant.secondary => (AppColors.secondary, AppColors.white, null, inactive ? <BoxShadow>[] : AppShadows.success),
      AppButtonVariant.danger    => (AppColors.error, AppColors.white, null, <BoxShadow>[]),
      AppButtonVariant.outlined  => (Colors.transparent, AppColors.primary, null, <BoxShadow>[]),
      AppButtonVariant.ghost     => (Colors.transparent, context.textPrimary, null, <BoxShadow>[]),
    };

    return Container(
      width: double.infinity,
      height: _height,
      decoration: BoxDecoration(
        gradient: inactive ? null : gradient,
        color: inactive ? context.elevatedColor : (gradient == null ? bg : null),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: variant == AppButtonVariant.outlined
            ? Border.all(color: inactive ? context.divColor : AppColors.primary, width: 1.5)
            : null,
        boxShadow: inactive ? null : shadows,
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          onTap: inactive ? null : () {
            HapticFeedback.lightImpact();
            onPressed?.call();
          },
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(AppColors.white)),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leadingIcon != null) ...[
                        Icon(leadingIcon, size: _fontSize + 2,
                            color: inactive ? context.textDisabled : fg),
                        const SizedBox(width: 6),
                      ],
                      Text(text, style: TextStyle(fontSize: _fontSize,
                          fontWeight: FontWeight.w700,
                          color: inactive ? context.textDisabled : fg)),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 6),
                        Icon(trailingIcon, size: _fontSize + 2,
                            color: inactive ? context.textDisabled : fg),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
