import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';

/// A floating pill that shows the current trip status with an optional pulse
/// animation for live states.
///
/// Previously duplicated as `_statusPill` in:
/// - user/trip_details_screen.dart
/// - driver/trip_details_screen.dart
/// - user/tracking_screen.dart
class TripStatusPill extends StatelessWidget {
  final String? status;
  final Animation<double> pulseAnimation;

  const TripStatusPill({
    super.key,
    required this.status,
    required this.pulseAnimation,
  });

  @override
  Widget build(BuildContext context) {
    final color = statusColor(context, status);
    final icon = statusIcon(status);
    final label = statusLabel(context, status);
    final live = status == 'in_progress' || status == 'searching';

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: pulseAnimation,
          builder: (_, child) => Transform.scale(
            scale: live ? (0.97 + 0.03 * pulseAnimation.value) : 1.0,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            decoration: BoxDecoration(
              color: context.cardColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(32),
              border:
                  Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 22,
                    spreadRadius: 2),
                BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.54),
                    blurRadius: 10),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (live)
                AnimatedBuilder(
                  animation: pulseAnimation,
                  builder: (_, __) => Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color:
                                color.withValues(alpha: pulseAnimation.value),
                            blurRadius: 8)
                      ],
                    ),
                  ),
                )
              else
                Icon(icon, color: color, size: 16),
              const SizedBox(width: 9),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2)),
            ]),
          ),
        ),
      ),
    );
  }

  /// Maps a status string to a color.
  static Color statusColor(BuildContext context, String? s) => switch (s) {
        'completed' => AppColors.success,
        'cancelled' => AppColors.error,
        'in_progress' || 'accepted' => AppColors.primary,
        'searching' => AppColors.warning,
        _ => context.textSecondary,
      };

  /// Maps a status string to an icon.
  static IconData statusIcon(String? s) => switch (s) {
        'completed' => Icons.check_circle_rounded,
        'cancelled' => Icons.cancel_rounded,
        'in_progress' => Icons.local_taxi_rounded,
        'accepted' => Icons.thumb_up_rounded,
        'searching' => Icons.radar_rounded,
        _ => Icons.help_outline_rounded,
      };

  /// Maps a status string to a localized label.
  static String statusLabel(BuildContext context, String? s) {
    final l = AppLocalizations.of(context)!;
    return switch (s) {
      'completed' => l.completed,
      'cancelled' => l.cancelled,
      'in_progress' => l.inProgress,
      'accepted' => l.tripAccepted,
      'searching' => l.searchingForDriver,
      _ => l.pending,
    };
  }
}
