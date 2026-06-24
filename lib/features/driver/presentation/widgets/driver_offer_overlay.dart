import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../features/trips/data/models/trip_model.dart';
import '../home/bloc/driver_home_bloc.dart';
import '../home/bloc/driver_home_event.dart';
import '../home/bloc/driver_home_state.dart';

class DriverOfferOverlay extends StatelessWidget {
  final Widget child;

  const DriverOfferOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DriverHomeBloc, DriverHomeState>(
      buildWhen: (prev, curr) =>
          (prev.pendingTripOffer == null && curr.pendingTripOffer != null) ||
          (prev.pendingTripOffer != null && curr.pendingTripOffer == null),
      builder: (context, state) {
        final offer = state.pendingTripOffer;
        return Stack(
          alignment: Alignment.topLeft,
          children: [
            child,
            if (offer != null) _buildOverlay(context, offer),
          ],
        );
      },
    );
  }

  Widget _buildOverlay(BuildContext context, TripModel trip) {
    final user = trip.userData;
    final userName =
        user?['name'] as String? ?? AppLocalizations.of(context)!.user;
    final avatarUrl = user?['avatar_url'] as String?;

    final price = trip.price;
    final distance = trip.distanceKm;
    final pickup = trip.pickupAddress;
    final destination = trip.destinationAddress;
    final vehicleType = trip.vehicleType;
    final paymentMethod = trip.paymentMethod ?? 'cash';

    final isCash = paymentMethod.toLowerCase() == 'cash';

    return Positioned.fill(
      child: Material(
        color: AppColors.black.withValues(alpha: 0.65),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, scale, child) {
                return Transform.scale(scale: scale, child: child);
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: context.divColor, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.local_taxi_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppLocalizations.of(context)!.newTripRequest,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${AppLocalizations.of(context)!.distanceWithKm(distance.toStringAsFixed(1))} · $vehicleType',
                                  style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              PriceFormatter.displayCompactWithCurrency(context, price),
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: context.elevatedColor,
                              image: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(avatarUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: avatarUrl == null || avatarUrl.isEmpty
                                ? Icon(
                                    Icons.person_rounded,
                                    color: context.textSecondary,
                                    size: 24,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      isCash
                                          ? Icons.payments_outlined
                                          : Icons.credit_card_outlined,
                                      size: 14,
                                      color: isCash
                                          ? AppColors.success
                                          : AppColors.primary,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      isCash
                                          ? AppLocalizations.of(context)!.cash
                                          : AppLocalizations.of(context)!
                                              .bankCard,
                                      style: TextStyle(
                                        color: isCash
                                            ? AppColors.success
                                            : AppColors.primary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _AddressRow(
                        icon: Icons.radio_button_on,
                        iconColor: AppColors.success,
                        label: AppLocalizations.of(context)!.meetingPointLabel,
                        value: pickup,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _AddressRow(
                        icon: Icons.location_on_rounded,
                        iconColor: AppColors.primary,
                        label: AppLocalizations.of(context)!.destination,
                        value: destination,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Negotiation Section
                    StatefulBuilder(
                      builder: (context, setState) {
                        double currentPrice = price;
                        return Column(
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        final tripId = trip.id;
                                        if (tripId.isEmpty) return;
                                        context.read<DriverHomeBloc>().add(
                                            SubmitTripOffer(
                                                tripId, price + 10));
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(
                                            color: AppColors.primary),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      child: Text(
                                          '+${AppLocalizations.of(context)!.priceWithCurrency('10', AppLocalizations.of(context)!.currencySar)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        final tripId = trip.id;
                                        if (tripId.isEmpty) return;
                                        context.read<DriverHomeBloc>().add(
                                            SubmitTripOffer(
                                                tripId, price + 20));
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.primary,
                                        side: const BorderSide(
                                            color: AppColors.primary),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                      child: Text(
                                          '+${AppLocalizations.of(context)!.priceWithCurrency('20', AppLocalizations.of(context)!.currencySar)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        final tripId = trip.id;
                                        if (tripId.isEmpty) return;
                                        context
                                            .read<DriverHomeBloc>()
                                            .add(RejectTripOffer(tripId));
                                      },
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: context.textPrimary,
                                        side:
                                            BorderSide(color: context.divColor),
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14)),
                                      ),
                                      child: Text(
                                          AppLocalizations.of(context)!.reject),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: AppButton(
                                      text: AppLocalizations.of(context)!.acceptTrip,
                                      onPressed: () {
                                        final tripId = trip.id;
                                        if (tripId.isEmpty) return;
                                        context
                                            .read<DriverHomeBloc>()
                                            .add(AcceptTripOffer(tripId));
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _AddressRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
