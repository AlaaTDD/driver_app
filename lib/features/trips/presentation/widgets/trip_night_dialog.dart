import 'package:flutter/material.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'trip_action_button.dart';

/// A confirmation dialog matching the app's dark design system.
///
/// Previously duplicated as `_NightDialog` in:
/// - user/trip_details_screen.dart
/// - driver/trip_details_screen.dart
class TripNightDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, body, confirmLabel, cancelLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;

  const TripNightDialog({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
    required this.cancelLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: iconColor.withValues(alpha: 0.25))),
                      child: Icon(icon, color: iconColor, size: 20)),
                  const SizedBox(width: 14),
                  Text(title,
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 14),
                Text(body,
                    style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                        height: 1.6)),
                const SizedBox(height: 24),
                Row(children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(cancelLabel,
                        style: TextStyle(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  TripActionButton(
                      label: confirmLabel,
                      icon: Icons.check_rounded,
                      color: confirmColor,
                      compact: true,
                      onTap: onConfirm),
                ]),
              ]),
        ),
      );
}

/// A styled text field matching the app's dark design system.
///
/// Previously duplicated as `_NightField` in:
/// - user/trip_details_screen.dart
/// - driver/trip_details_screen.dart
class TripNightField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;

  const TripNightField({
    super.key,
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(color: context.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: TextStyle(color: context.textSecondary),
          hintStyle: TextStyle(color: context.textDisabled),
          prefixIcon: Icon(icon, color: context.textSecondary, size: 18),
          filled: true,
          fillColor: context.elevatedColor,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: context.divColor)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.error, width: 1.5)),
        ),
        validator: validator,
      );
}
