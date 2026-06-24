import 'package:flutter/material.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/models/trip_details_model.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/utils/price_formatter.dart';

/// Displays fare details: hero price, paid/unpaid badge, and optional coupon discount.
///
/// Previously duplicated as `_PriceBox` in:
/// - user/trip_details_screen.dart
/// - driver/trip_details_screen.dart
class TripPriceBox extends StatelessWidget {
  final TripDetailsModel trip;
  const TripPriceBox({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final price = trip.price ?? 0;
    final discount = trip.couponDiscount ?? 0;
    final finalPrice = price - discount;
    final isPaid = trip.isPaid;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.fareDetails.toUpperCase(),
            style: TextStyle(
                color: context.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8)),
        const SizedBox(height: 10),

        // hero number
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(PriceFormatter.display(context, finalPrice),
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1)),
              const SizedBox(width: 5),
              Text(l.currencySar,
                  style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),

        const Spacer(),

        // paid badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPaid
                ? AppColors.success.withValues(alpha: 0.1)
                : AppColors.warning.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isPaid
                    ? AppColors.success.withValues(alpha: 0.28)
                    : AppColors.warning.withValues(alpha: 0.28)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: isPaid ? AppColors.success : AppColors.warning,
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(isPaid ? l.paid : l.unpaid,
                style: TextStyle(
                    color: isPaid ? AppColors.success : AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),

        if (discount > 0) ...[
          const SizedBox(height: 8),
          Text(
              '-${PriceFormatter.displayWithCurrency(context, discount)}',
              style: TextStyle(
                  color: AppColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}
