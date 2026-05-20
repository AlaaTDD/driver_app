import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/app_routes.dart';
import '../../../../../core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';

class TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isActive;

  const TripCard({super.key, required this.trip, this.isActive = false});

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (e, st) {
      debugPrint('⚠️ TripCard: invalid created_at "$createdAt": $e\n$st');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final status = trip['status'] as String?;
    final distance = (trip['distance_km'] as num?)?.toStringAsFixed(1) ?? '0';
    final price = (trip['price'] as num?)?.toDouble() ?? 0;
    final couponDiscount = (trip['coupon_discount'] as num?)?.toDouble() ?? 0;
    final displayPrice = (trip['final_price'] as num?)?.toDouble() ?? price;
    final pickup = trip['pickup_address'] as String? ??
        trip['meeting_address'] as String? ??
        '';
    final dest = trip['destination_address'] as String? ?? '';
    final time = _formatTime(trip['created_at'] as String?);

    final statusColor = _statusColor(context, status);
    final statusLabel = _statusLabel(status, l);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
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
            onTap: () => context
                .push('${AppRoutes.userTripDetails}?tripId=${trip['id']}'),
            splashColor: AppColors.primary.withValues(alpha: 0.08),
            highlightColor: context.elevatedColor.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ──────────────────────────────────────────────
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
                          style: TextStyle(color: context.textSecondary, fontSize: 12)),
                    ],
                  ]),

                  const SizedBox(height: 14),

                  // ── Route ──────────────────────────────────────────────────
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
                                color: AppColors.success.withValues(alpha: 0.4),
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
                                color: AppColors.primary.withValues(alpha: 0.4),
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

                  // ── Footer: distance + price ────────────────────────────────
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
                          border:
                              Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_offer_rounded,
                              size: 10, color: AppColors.purple),
                          const SizedBox(width: 3),
                          Text('-${couponDiscount.toStringAsFixed(0)}',
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
                          l.priceWithCurrency(
                              displayPrice.toStringAsFixed(0), l.currencySar),
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

  Color _statusColor(BuildContext context, String? s) => switch (s) {
        'completed' => AppColors.success,
        'cancelled' => AppColors.error,
        'in_progress' || 'accepted' => AppColors.primary,
        'searching' => AppColors.warning,
        _ => context.textSecondary,
      };

  String _statusLabel(String? s, AppLocalizations l) => switch (s) {
        'completed' => l.completed,
        'cancelled' => l.cancelled,
        'in_progress' => l.inProgress,
        'accepted' => l.tripAccepted,
        'searching' => l.searchingForDriver,
        _ => l.pending,
      };
}
