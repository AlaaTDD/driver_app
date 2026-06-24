import 'package:flutter/material.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/models/trip_details_model.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

/// Displays trip stats: distance, vehicle type, and payment method.
///
/// Previously duplicated as `_StatsBox` in:
/// - user/trip_details_screen.dart
/// - driver/trip_details_screen.dart
class TripStatsBox extends StatelessWidget {
  final TripDetailsModel trip;
  const TripStatsBox({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final dist = trip.distanceKm?.toStringAsFixed(1) ?? '0';
    final vType = trip.vehicleType ?? 'car';
    final pay = trip.paymentMethod ?? 'cash';

    final vName = switch (vType) {
      'sedan' => l.sedan,
      'suv' => l.suv,
      'van' => l.van,
      'minibus' => l.minibus,
      'motorcycle' => l.motorcycle,
      _ => l.car,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.tripDetails.toUpperCase(),
            style: TextStyle(
                color: context.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8)),
        const SizedBox(height: 14),
        _StatRow(
            icon: Icons.straighten_rounded,
            color: AppColors.primary,
            label: l.distanceWithKm(dist)),
        const SizedBox(height: 10),
        _StatRow(
            icon: Icons.directions_car_rounded,
            color: AppColors.purple,
            label: vName),
        const SizedBox(height: 10),
        _StatRow(
          icon: pay == 'cash'
              ? Icons.payments_rounded
              : Icons.credit_card_rounded,
          color: AppColors.warning,
          label: pay == 'cash' ? l.cash : l.bankCard,
        ),
      ]),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _StatRow(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14)),
        const SizedBox(width: 10),
        Flexible(
            child: Text(label,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
      ]);
}
