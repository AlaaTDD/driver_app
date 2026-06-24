import 'package:flutter/material.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

/// Header card for trips screen showing back button, title, stats, and new trip button.
///
/// Previously duplicated as:
/// - `TripsHeader` in user/trips/widgets/trips_header.dart
/// - `_TripsHeader` inline in driver/trips/driver_trips_screen.dart
class SharedTripsHeader extends StatelessWidget {
  final int total;
  final int completed;
  final int cancelled;
  final VoidCallback onBack;
  final VoidCallback? onNewTrip;

  const SharedTripsHeader({
    super.key,
    required this.total,
    required this.completed,
    required this.cancelled,
    required this.onBack,
    this.onNewTrip,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final card = context.cardColor;
    final elevated = context.elevatedColor;
    final border = context.divColor;
    const blue = AppColors.primary;
    const emerald = AppColors.secondary;
    const rose = AppColors.error;
    final t1 = context.textPrimary;
    final t2 = context.textSecondary;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: blue.withValues(alpha: 0.25), width: 1),
        boxShadow: [
          BoxShadow(
              color: blue.withValues(alpha: 0.10),
              blurRadius: 20,
              offset: const Offset(0, 6)),
          BoxShadow(
              color: AppColors.black.withValues(alpha: 0.38), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: back + title + new trip ─────────────────────
          Row(children: [
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: elevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: border, width: 1),
                ),
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    color: t1, size: 16),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(l.myTrips,
                      style: TextStyle(
                          color: t1,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.2)),
                  const SizedBox(height: 2),
                  Text(l.totalTripsLabel(total),
                      style: TextStyle(
                          color: t2, fontSize: 12, height: 1.2)),
                ])),
            if (onNewTrip != null)
              GestureDetector(
                onTap: onNewTrip,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [blue, AppColors.primaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                          color: blue.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_rounded,
                        color: AppColors.white, size: 15),
                    const SizedBox(width: 5),
                    Text(l.newTripLabel,
                        style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
          ]),

          const SizedBox(height: 16),
          Container(height: 1, color: border),
          const SizedBox(height: 14),

          // ── Stats row ────────────────────────────────────────────
          Row(children: [
            Expanded(
                child: _StatChip(
              icon: Icons.check_circle_rounded,
              value: completed.toString(),
              label: l.completed,
              color: emerald,
            )),
            const SizedBox(width: 10),
            Expanded(
                child: _StatChip(
              icon: Icons.cancel_rounded,
              value: cancelled.toString(),
              label: l.cancelled,
              color: rose,
            )),
          ]),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final elevated = context.elevatedColor;
    final t1 = context.textPrimary;
    final t2 = context.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: elevated,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value,
              style: TextStyle(
                  color: t1,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.2)),
          Text(label,
              style: TextStyle(color: t2, fontSize: 11, height: 1.2)),
        ])),
      ]),
    );
  }
}
