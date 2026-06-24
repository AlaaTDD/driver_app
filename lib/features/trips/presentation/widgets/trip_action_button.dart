import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

/// A gradient or outlined action button used across trip-detail screens.
///
/// Previously duplicated as `_Btn` in:
/// - user/trip_details_screen.dart
/// - driver/trip_details_screen.dart
class TripActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final bool compact;
  final VoidCallback onTap;

  const TripActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: compact ? 44 : 50,
          padding: compact ? const EdgeInsets.symmetric(horizontal: 20) : null,
          decoration: BoxDecoration(
            gradient: outlined
                ? null
                : LinearGradient(
                    colors: [color, color.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(14),
            border: outlined
                ? Border.all(color: color.withValues(alpha: 0.5), width: 1.2)
                : null,
            boxShadow: outlined
                ? null
                : [
                    BoxShadow(
                        color: color.withValues(alpha: 0.26),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
          ),
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: outlined ? color : AppColors.white, size: 17),
              const SizedBox(width: 7),
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: outlined ? color : AppColors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      );
}
