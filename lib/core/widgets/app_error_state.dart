import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_spacing.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

class AppErrorState extends StatelessWidget {
  final String? message;
  final VoidCallback? onRetry;
  final String retryLabel;

  const AppErrorState({
    super.key,
    this.message,
    this.onRetry,
    this.retryLabel = 'إعادة المحاولة',
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
              message ?? 'حدث خطأ غير متوقع',
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(retryLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
