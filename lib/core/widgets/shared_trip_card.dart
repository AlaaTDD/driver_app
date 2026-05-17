import 'package:flutter/material.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/app_radius.dart';
import 'package:snapix/core/theme/app_spacing.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/utils/trip_status.dart';
import 'package:snapix/core/widgets/app_trip_status_chip.dart';

class SharedTripCard extends StatelessWidget {
  final String tripId;
  final TripStatus status;
  final String originAddress;
  final String destinationAddress;
  final String formattedDate;
  final String formattedPrice;
  final bool isDriver;
  final String? counterpartName;
  final VoidCallback? onTap;
  final String Function(TripStatus) statusLabelBuilder;

  const SharedTripCard({
    super.key,
    required this.tripId,
    required this.status,
    required this.originAddress,
    required this.destinationAddress,
    required this.formattedDate,
    required this.formattedPrice,
    required this.statusLabelBuilder,
    this.isDriver = false,
    this.counterpartName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: AppSpacing.card,
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: AppRadius.xl_,
          border: Border.all(color: context.divColor, width: .8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(formattedDate,
                      style: TextStyle(
                          color: context.textSecondary, fontSize: 12)),
                ),
                AppTripStatusChip(
                    status: status, labelBuilder: statusLabelBuilder),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            _LocationRow(
                icon: Icons.radio_button_checked_rounded,
                color: AppColors.primary,
                address: originAddress),
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: Container(
                  width: 2,
                  height: 16,
                  decoration: BoxDecoration(
                      color: context.divColor, borderRadius: AppRadius.full_)),
            ),
            _LocationRow(
                icon: Icons.location_on_rounded,
                color: AppColors.error,
                address: destinationAddress),
            const SizedBox(height: AppSpacing.md),
            Divider(color: context.divColor, thickness: .6, height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (counterpartName != null)
                  Expanded(
                      child: Text(counterpartName!,
                          style: TextStyle(
                              color: context.textSecondary, fontSize: 13))),
                Text(formattedPrice,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String address;
  const _LocationRow(
      {required this.icon, required this.color, required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(address,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
