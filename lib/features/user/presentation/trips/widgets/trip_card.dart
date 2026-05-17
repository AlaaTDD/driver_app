
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/constants/app_routes.dart';
import '../../../../../core/localization/generated/app_localizations.dart';
import 'package:snapix/core/theme/app_colors.dart';

// Shared color tokens — mirrors trip_details_screen._C
const _bg      = AppColors.background;
const _card    = AppColors.surface;
const _elevated= AppColors.surfaceElevated;
const _border  = AppColors.divider;
const _blue    = AppColors.primary;
const _emerald = AppColors.secondary;
const _rose    = AppColors.error;
const _amber   = AppColors.warning;
const _violet  = AppColors.purple;
const _t1      = AppColors.textPrimary;
const _t2      = AppColors.textSecondary;
const _t3      = AppColors.textDisabled;

class TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isActive;

  const TripCard({super.key, required this.trip, this.isActive = false});

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
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
    final pickup = trip['pickup_address'] as String? ?? trip['meeting_address'] as String? ?? '';
    final dest = trip['destination_address'] as String? ?? '';
    final time = _formatTime(trip['created_at'] as String?);

    final statusColor = _statusColor(status);
    final statusLabel = _statusLabel(status, l);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: isActive
            ? Border.all(color: _blue.withValues(alpha: 0.4), width: 1.5)
            : Border.all(color: _border, width: 1),
        boxShadow: isActive
            ? [BoxShadow(color: _blue.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 4))]
            : [BoxShadow(color: AppColors.black.withValues(alpha: 0.26), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: AppColors.transparent,
          child: InkWell(
            onTap: () => context.push('${AppRoutes.userTripDetails}?tripId=${trip['id']}'),
            splashColor: _blue.withValues(alpha: 0.08),
            highlightColor: _elevated.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ──────────────────────────────────────────────
                  Row(children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 6, height: 6,
                          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(statusLabel, style: TextStyle(
                          color: statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                    const Spacer(),
                    if (time.isNotEmpty) ...[
                      const Icon(Icons.access_time_rounded, size: 12, color: _t3),
                      const SizedBox(width: 4),
                      Text(time, style: const TextStyle(color: _t2, fontSize: 12)),
                    ],
                  ]),

                  const SizedBox(height: 14),

                  // ── Route ──────────────────────────────────────────────────
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Dots + line
                    Column(children: [
                      Container(
                        width: 9, height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: _emerald,
                          boxShadow: [BoxShadow(color: _emerald.withValues(alpha: 0.4), blurRadius: 5)],
                        ),
                      ),
                      Container(
                        width: 1.5, height: 28,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [_emerald.withValues(alpha: 0.4), _blue.withValues(alpha: 0.4)],
                            begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      Container(
                        width: 9, height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, color: _blue,
                          boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.4), blurRadius: 5)],
                        ),
                      ),
                    ]),
                    const SizedBox(width: 10),
                    // Addresses
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        pickup.isEmpty ? '---' : pickup,
                        style: const TextStyle(color: _t1, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        dest.isEmpty ? '---' : dest,
                        style: const TextStyle(color: _t1, fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ])),
                  ]),

                  const SizedBox(height: 14),
                  Container(height: 1, color: _border),
                  const SizedBox(height: 12),

                  // ── Footer: distance + price ────────────────────────────────
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _elevated,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.straighten_rounded, size: 12, color: _t2),
                        const SizedBox(width: 4),
                        Text('$distance ${l.km}',
                          style: const TextStyle(color: _t2, fontSize: 11, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                    // Coupon discount badge (if applicable)
                    if (couponDiscount > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        decoration: BoxDecoration(
                          color: _violet.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _violet.withValues(alpha: 0.3)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_offer_rounded, size: 10, color: _violet),
                          const SizedBox(width: 3),
                          Text('-${couponDiscount.toStringAsFixed(0)}',
                            style: const TextStyle(color: _violet, fontSize: 10, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ],
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_blue, AppColors.primaryDark],
                          begin: Alignment.topLeft, end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Text('${displayPrice.toStringAsFixed(0)} ${l.currencySar}',
                        style: const TextStyle(color: AppColors.white, fontSize: 14, fontWeight: FontWeight.w800)),
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

  Color _statusColor(String? s) => switch (s) {
    'completed'                   => _emerald,
    'cancelled'                   => _rose,
    'in_progress' || 'accepted'   => _blue,
    'searching'                   => _amber,
    _                             => _t2,
  };

  String _statusLabel(String? s, AppLocalizations l) => switch (s) {
    'completed'   => l.completed,
    'cancelled'   => l.cancelled,
    'in_progress' => l.inProgress,
    'accepted'    => l.tripAccepted,
    'searching'   => l.searchingForDriver,
    _             => l.pending,
  };
}
