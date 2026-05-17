import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_spacing.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/widgets/app_button.dart';
import 'package:snapix/core/widgets/bottom_sheet_container.dart';

class AppConfirmSheet extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final bool isDangerous;

  const AppConfirmSheet({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmLabel = 'تأكيد',
    this.cancelLabel = 'إلغاء',
    this.isDangerous = false,
  });

  static Future<bool> show(BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    bool isDangerous = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppConfirmSheet(
        title: title, message: message,
        confirmLabel: confirmLabel, cancelLabel: cancelLabel,
        isDangerous: isDangerous,
        onConfirm: () => Navigator.pop(context, true),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(color: context.textPrimary,
              fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: context.textSecondary, fontSize: 14, height: 1.5)),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            text: confirmLabel,
            variant: isDangerous ? AppButtonVariant.danger : AppButtonVariant.primary,
            onPressed: () { Navigator.pop(context, true); onConfirm(); },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            text: cancelLabel,
            variant: AppButtonVariant.ghost,
            onPressed: () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}
