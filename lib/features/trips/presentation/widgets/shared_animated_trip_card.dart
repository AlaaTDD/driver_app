import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'package:snapix/core/utils/price_formatter.dart';
import 'package:snapix/core/utils/trip_status.dart';
import 'package:snapix/features/trips/data/models/trip_model.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

/// A unified trip card used by **both** User and Driver trips screens.
///
/// Differences between user/driver are handled via [detailsRoute] and
/// optional [onTap]. Additional fields (coupon discount) are shown when
/// present on the [TripModel].
///
/// Previously duplicated as:
/// - `TripCard` in user/trips/widgets/trip_card.dart
/// - `_TripCard` in driver/trips/driver_trips_screen.dart
class SharedAnimatedTripCard extends StatefulWidget {
  final TripModel trip;
  final bool isActive;
  final int delay;
  final String detailsRoute;

  const SharedAnimatedTripCard({
    super.key,
    required this.trip,
    required this.detailsRoute,
    this.isActive = false,
    this.delay = 0,
  });

  @override
  State<SharedAnimatedTripCard> createState() => _SharedAnimatedTripCardState();
}

class _SharedAnimatedTripCardState extends State<SharedAnimatedTripCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: _TripCardContent(
          trip: widget.trip,
          isActive: widget.isActive,
          detailsRoute: widget.detailsRoute,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL CARD CONTENT
// ─────────────────────────────────────────────────────────────────────────────

class _TripCardContent extends StatelessWidget {
  final TripModel trip;
  final bool isActive;
  final String detailsRoute;

  const _TripCardContent({
    required this.trip,
    this.isActive = false,
    required this.detailsRoute,
  });

  String _formatTime(DateTime? createdAt) {
    if (createdAt == null) return '';
    final dt = createdAt.toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = trip.status;
    final distance = trip.distanceKm?.toStringAsFixed(1) ?? '0';
    final price = trip.price ?? 0;
    final couponDiscount = trip.couponDiscount ?? 0;
    final displayPrice = trip.finalPrice ?? price;
    final pickup = trip.pickupAddress ?? trip.meetingAddress ?? '';
    final dest = trip.destinationAddress ?? '';
    final time = _formatTime(trip.createdAt);

    final statusColor = _statusColor(context, status);
    final statusLabel = _statusLabel(status, l);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? Border.all(
                color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
            : Border.all(color: context.divColor, width: 1),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ]
            : [
                BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.26),
                    blurRadius: 8,
                    offset: Offset(0, 2))
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: () =>
                context.push('$detailsRoute?tripId=${trip.id}'),
            splashColor: AppColors.primary.withValues(alpha: 0.08),
            highlightColor: context.elevatedColor.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ────────────────────────────────────────────
                  Row(children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                            width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                              color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(statusLabel,
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const Spacer(),
                    if (time.isNotEmpty) ...[
                      Icon(Icons.access_time_rounded,
                          size: 12, color: context.textDisabled),
                      const SizedBox(width: 4),
                      Text(time,
                          style: TextStyle(
                              color: context.textSecondary, fontSize: 12)),
                    ],
                  ]),

                  const SizedBox(height: 14),

                  // ── Route ─────────────────────────────────────────────────
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Dots + line
                    Column(children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success,
                          boxShadow: [
                            BoxShadow(
                                color:
                                    AppColors.success.withValues(alpha: 0.4),
                                blurRadius: 5)
                          ],
                        ),
                      ),
                      Container(
                        width: 1.5,
                        height: 28,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.success.withValues(alpha: 0.4),
                              AppColors.primary.withValues(alpha: 0.4)
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 5)
                          ],
                        ),
                      ),
                    ]),
                    const SizedBox(width: 10),
                    // Addresses
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                            pickup.isEmpty ? l.notAvailable : pickup,
                            style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            dest.isEmpty ? l.notAvailable : dest,
                            style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.3),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ])),
                  ]),

                  const SizedBox(height: 14),
                  Container(height: 1, color: context.divColor),
                  const SizedBox(height: 12),

                  // ── Footer: distance + price ──────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: context.elevatedColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.divColor),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.straighten_rounded,
                            size: 12, color: context.textSecondary),
                        const SizedBox(width: 4),
                        Text(l.distanceWithKm(distance),
                            style: TextStyle(
                                color: context.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    // Coupon discount badge (if applicable)
                    if (couponDiscount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.purple.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_offer_rounded,
                              size: 10, color: AppColors.purple),
                          const SizedBox(width: 3),
                          Text('-${PriceFormatter.display(context, couponDiscount)}',
                              style: const TextStyle(
                                  color: AppColors.purple,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 2))
                        ],
                      ),
                      child: Text(
                          PriceFormatter.displayCompactWithCurrency(
                              context, displayPrice),
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(BuildContext context, TripStatus s) => switch (s) {
        TripStatus.completed => AppColors.success,
        TripStatus.cancelled => AppColors.error,
        TripStatus.inProgress ||
        TripStatus.accepted ||
        TripStatus.driverArriving =>
          AppColors.primary,
        TripStatus.searching || TripStatus.scheduled => AppColors.warning,
        _ => context.textSecondary,
      };

  String _statusLabel(TripStatus s, AppLocalizations l) => switch (s) {
        TripStatus.completed => l.completed,
        TripStatus.cancelled => l.cancelled,
        TripStatus.inProgress => l.inProgress,
        TripStatus.driverArriving =>
          l.localeName.startsWith('ar') ? 'السائق في الطريق' : 'Driver arriving',
        TripStatus.accepted => l.tripAccepted,
        TripStatus.searching => l.searchingForDriver,
        TripStatus.scheduled =>
          l.localeName.startsWith('ar') ? 'مجدولة' : 'Scheduled',
        _ => l.pending,
      };
}
