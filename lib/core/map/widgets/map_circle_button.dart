import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

/// A 42 × 42 translucent circle button used as floating map controls.
///
/// Previously duplicated as `_MapCircleBtn` in:
/// - user/trip_details_screen.dart
/// - driver/trip_details_screen.dart
/// - user/tracking_screen.dart
class MapCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const MapCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.cardColor.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: context.divColor, width: 1),
            boxShadow: [
              BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.38),
                  blurRadius: 10)
            ],
          ),
          child: Icon(icon, color: context.textPrimary, size: 18),
        ),
      );
}
