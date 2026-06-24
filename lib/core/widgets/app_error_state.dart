import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_spacing.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/widgets/app_button.dart';
import '../localization/generated/app_localizations.dart';

class AppErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  const AppErrorState({
    super.key,
    this.message,
    this.onRetry,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                  color: AppColors.errorSurface, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded,
                  size: 32, color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message ?? AppLocalizations.of(context)?.errorUnexpected ?? '',
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton(
                text: retryLabel ?? AppLocalizations.of(context)?.retry ?? '',
                onPressed: onRetry,
                variant: AppButtonVariant.outlined,
                size: AppButtonSize.md,
                leadingIcon: Icons.refresh_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
