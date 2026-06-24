import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/models/trip_offer_model.dart';
import 'package:snapix/core/theme/app_colors.dart';

import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/utils/app_logger.dart';

class DriverRequestFeedScreen extends StatefulWidget {
  const DriverRequestFeedScreen({super.key});

  @override
  State<DriverRequestFeedScreen> createState() =>
      _DriverRequestFeedScreenState();
}

class _DriverRequestFeedScreenState extends State<DriverRequestFeedScreen> {
  StreamSubscription? _sub;
  List<TripOfferModel> _offers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    final driverId = SupabaseService.currentUser?.id;
    if (driverId == null) return;

    _sub = SupabaseService.client
        .from('trip_offers')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .listen((rows) {
          if (!mounted) return;
          // Only show pending offers; realtime removes the card when status changes
          final pending = rows
              .where((r) => r['status'] == 'pending')
              .map((r) => TripOfferModel.fromJson(r))
              .toList()
            ..sort((a, b) {
              final aDate = a.createdAt ?? DateTime(1970);
              final bDate = b.createdAt ?? DateTime(1970);
              return aDate.compareTo(bDate);
            });
          setState(() {
            _offers = pending;
            _loading = false;
          });
        }, onError: (_) => setState(() => _loading = false));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _accept(String offerId, String tripId) async {
    try {
      final result = await SupabaseService.client
          .rpc('driver_accept_trip', params: {'p_trip_id': tripId});
      if (result != null && result['success'] == true && mounted) {
        context.push('${AppRoutes.driverTripDetails}?tripId=$tripId');
      }
    } catch (e) {
      AppLogger.debug('RequestFeed: accept failed — $e');
    }
  }

  Future<void> _reject(String _, String tripId) async {
    try {
      await SupabaseService.client
          .rpc('driver_reject_trip', params: {'p_trip_id': tripId});
      // Realtime stream will remove the card automatically
    } catch (e) {
      AppLogger.debug('RequestFeed: reject failed — $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: SafeArea(
          child: Column(children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.divColor),
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: context.textPrimary, size: 17),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.rideRequests,
                            style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _loading
                                ? l.loading
                                : _offers.isEmpty
                                    ? l.noRideRequestsAvailableNow
                                    : l.availableRequestsCount(_offers.length),
                            key: ValueKey(_offers.length),
                            style: TextStyle(
                                color: context.textSecondary, fontSize: 12),
                          ),
                        ),
                      ]),
                ),
                // Live indicator dot
                if (!_loading)
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _offers.isEmpty
                          ? context.textDisabled
                          : AppColors.success,
                      shape: BoxShape.circle,
                      boxShadow: _offers.isEmpty
                          ? null
                          : [
                              BoxShadow(
                                  color:
                                      AppColors.success.withValues(alpha: 0.5),
                                  blurRadius: 8),
                            ],
                    ),
                  ),
              ]),
            ),

            // ── Content ─────────────────────────────────────────────────────
            Expanded(
                child: _loading
                    ? const Center(
                        child: const CircularProgressIndicator(
                            color: AppColors.primary, strokeWidth: 2))
                    : _offers.isEmpty
                        ? _buildEmpty(l)
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: _offers.length,
                            itemBuilder: (_, i) => _OfferCard(
                              key: ValueKey(_offers[i].id),
                              offer: _offers[i],
                              onAccept: _accept,
                              onReject: _reject,
                            ),
                          )),
          ]),
        ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: context.elevatedColor,
            shape: BoxShape.circle,
            border: Border.all(color: context.divColor),
          ),
          child:
              Icon(Icons.inbox_rounded, color: context.textDisabled, size: 40),
        ),
        const SizedBox(height: 20),
        Text(l.noRideRequestsAvailable,
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(l.rideRequestsWillAppearHere,
            style: TextStyle(color: context.textSecondary, fontSize: 13)),
      ]),
    );
  }
}

// ─── Single offer card with countdown timer ───────────────────────────────────
class _OfferCard extends StatefulWidget {
  final TripOfferModel offer;
  final Future<void> Function(String offerId, String tripId) onAccept;
  final Future<void> Function(String offerId, String tripId) onReject;

  const _OfferCard({
    super.key,
    required this.offer,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_OfferCard> createState() => _OfferCardState();
}

class _OfferCardState extends State<_OfferCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;
  Timer? _timer;
  int _seconds = 30;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));
    _slideCtrl.forward();

    // Compute remaining seconds from created_at + 30s window
    final createdAt = widget.offer.createdAt;
    if (createdAt != null) {
      final elapsed = DateTime.now().difference(createdAt).inSeconds;
      _seconds = (30 - elapsed).clamp(0, 30);
    }

    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_seconds <= 1) {
        _timer?.cancel();
        // Auto-expire: reject silently
        widget.onReject(widget.offer.id, widget.offer.tripId);
        return;
      }
      setState(() => _seconds--);
    });
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final offerId = widget.offer.id;
    final tripId = widget.offer.tripId;
    final pickup = widget.offer.pickupAddress ?? l.notAvailable;
    final dest = widget.offer.destinationAddress ?? l.notAvailable;
    final price = widget.offer.proposedPrice;
    final distance = widget.offer.distanceKm?.toStringAsFixed(1);
    final timerFraction = _seconds / 30.0;
    final timerColor = _seconds > 15
        ? AppColors.success
        : _seconds > 8
            ? AppColors.warning
            : AppColors.error;

    return SlideTransition(
      position: _slideAnim,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: context.divColor),
          boxShadow: [
            BoxShadow(
                color: AppColors.black.withValues(alpha: 0.26),
                blurRadius: 16,
                offset: Offset(0, 4))
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // ── Timer bar ────────────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              height: 4,
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: timerFraction,
                child: Container(color: timerColor),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Route info ───────────────────────────────────────────────
                  Row(children: [
                    Column(children: [
                      Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle)),
                      Container(width: 1, height: 28, color: context.divColor),
                      Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                              color: AppColors.error, shape: BoxShape.circle)),
                    ]),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(pickup,
                            style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 14),
                        Text(dest,
                            style: TextStyle(
                                color: context.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    )),
                    // Timer circle
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: timerColor.withValues(alpha: 0.5), width: 2),
                        color: timerColor.withValues(alpha: 0.08),
                      ),
                      child: Center(
                          child: Text('$_seconds',
                              style: TextStyle(
                                  color: timerColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800))),
                    ),
                  ]),

                  const SizedBox(height: 14),

                  // ── Stats row ───────────────────────────────────────────────
                  Row(children: [
                    if (price != null)
                      _StatChip(
                        icon: Icons.attach_money_rounded,
                        label:
                            PriceFormatter.displayCompactWithCurrency(context, price),
                        color: AppColors.warning,
                      ),
                    if (distance != null) ...[
                      const SizedBox(width: 8),
                      _StatChip(
                        icon: Icons.straighten_rounded,
                        label: l.distanceWithKm(distance.toString()),
                        color: AppColors.primary,
                      ),
                    ],
                  ]),

                  const SizedBox(height: 14),

                  // ── Action buttons ──────────────────────────────────────────
                  Row(children: [
                    // Reject
                    Expanded(
                      child: GestureDetector(
                        onTap: _acting
                            ? null
                            : () async {
                                setState(() => _acting = true);
                                _timer?.cancel();
                                await widget.onReject(offerId, tripId);
                              },
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.5)),
                            color: AppColors.error.withValues(alpha: 0.06),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.close_rounded,
                                    color: AppColors.error, size: 18),
                                const SizedBox(width: 6),
                                Text(l.rejectBtn,
                                    style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ]),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Accept
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: _acting || tripId.isEmpty
                            ? null
                            : () async {
                                setState(() => _acting = true);
                                _timer?.cancel();
                                await widget.onAccept(offerId, tripId);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: _acting
                                ? null
                                : const LinearGradient(
                                    colors: [
                                      AppColors.success,
                                      AppColors.success
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                            color: _acting ? context.elevatedColor : null,
                            boxShadow: _acting
                                ? null
                                : [
                                    BoxShadow(
                                        color: AppColors.success
                                            .withValues(alpha: 0.35),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4)),
                                  ],
                          ),
                          child: _acting
                              ? const Center(
                                  child: SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          color: AppColors.white,
                                          strokeWidth: 2)))
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                      const Icon(Icons.check_rounded,
                                          color: AppColors.white, size: 18),
                                      const SizedBox(width: 6),
                                      Text(l.acceptRide,
                                          style: const TextStyle(
                                              color: AppColors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700)),
                                    ]),
                        ),
                      ),
                    ),
                  ]),
                ]),
          ),
        ]),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _StatChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
      );
}
