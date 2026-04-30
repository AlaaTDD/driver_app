// lib/features/user/presentation/searching/searching_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bloc/searching_bloc.dart';
import 'bloc/searching_event.dart';
import 'bloc/searching_state.dart';
import '../../../../core/constants/map_styles.dart';
import '../../../../core/constants/env_constants.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/directions_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';

class SearchingScreen extends StatefulWidget {
  final String tripId;
  final double? originLat;
  final double? originLng;
  final double? destLat;
  final double? destLng;

  const SearchingScreen({
    super.key,
    required this.tripId,
    this.originLat,
    this.originLng,
    this.destLat,
    this.destLng,
  });

  @override
  State<SearchingScreen> createState() => _SearchingScreenState();
}

class _SearchingScreenState extends State<SearchingScreen>
    with SingleTickerProviderStateMixin {
  final _mapCtrl = Completer<GoogleMapController>();
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    context.read<SearchingBloc>().add(StartSearching(widget.tripId));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.15).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _fetchRoute();
  }

  Future<void> _fetchRoute() async {
    if (widget.originLat == null || widget.destLat == null) return;
    final result = await DirectionsService.getRoute(
      originLat: widget.originLat!, originLng: widget.originLng!,
      destLat: widget.destLat!, destLng: widget.destLng!,
      apiKey: EnvConstants.googleMapsApiKey,
    );
    if (!mounted || result == null) return;
    setState(() => _routePoints = result.points);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BlocListener<SearchingBloc, SearchingState>(
      listener: (context, state) {
        if (state is SearchingSuccess) {
          context.go('${AppRoutes.userTracking}?tripId=${state.trip['id']}');
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // ── Full-screen map ─────────────────────────────────────────────
            Positioned.fill(child: _buildMap(isDark)),

            // ── Bottom sheet ────────────────────────────────────────────────
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: BlocBuilder<SearchingBloc, SearchingState>(
                builder: (ctx, state) => _buildBottomSheet(ctx, state, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    final hasRoute = widget.originLat != null && widget.destLat != null;
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    if (hasRoute) {
      final origin = LatLng(widget.originLat!, widget.originLng!);
      final dest = LatLng(widget.destLat!, widget.destLng!);
      markers.addAll([
        Marker(markerId: const MarkerId('o'), position: origin,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
        Marker(markerId: const MarkerId('d'), position: dest,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
      ]);
      final pts = _routePoints.isNotEmpty ? _routePoints : [origin, dest];
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: pts,
        color: AppColors.primary,
        width: 5,
        patterns: _routePoints.isNotEmpty ? [] : [PatternItem.dash(24), PatternItem.gap(10)],
      ));
    }

    final initPos = hasRoute
        ? CameraPosition(target: LatLng(widget.originLat!, widget.originLng!), zoom: 13)
        : const CameraPosition(target: AppConstants.defaultMapCenter, zoom: 13);

    return GoogleMap(
      initialCameraPosition: initPos,
      onMapCreated: (ctrl) {
        if (!_mapCtrl.isCompleted) {
          _mapCtrl.complete(ctrl);
          if (hasRoute) {
            Future.delayed(const Duration(milliseconds: 400), () {
              final bounds = LatLngBounds(
                southwest: LatLng(math.min(widget.originLat!, widget.destLat!), math.min(widget.originLng!, widget.destLng!)),
                northeast: LatLng(math.max(widget.originLat!, widget.destLat!), math.max(widget.originLng!, widget.destLng!)),
              );
              ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
            });
          }
        }
      },
      markers: markers,
      polylines: polylines,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      style: isDark ? kDarkMapStyle : kLightMapStyle,
      padding: const EdgeInsets.only(bottom: 300),
    );
  }

  Widget _buildBottomSheet(BuildContext context, SearchingState state, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1526) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(0, -4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -1)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(color: context.divColor, borderRadius: BorderRadius.circular(100)),
          ),
          // Route info strip (always visible)
          if (widget.originLat != null && widget.destLat != null)
            _buildRouteStrip(context, isDark),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: _buildSheetContent(context, state, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStrip(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.success)),
            Container(width: 1, height: 10, color: const Color(0xFF64748B)),
            Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.error)),
          ]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(AppLocalizations.of(context)!.startingPoint, style: TextStyle(color: context.textSecondary, fontSize: 10, fontWeight: FontWeight.w400)),
              Divider(color: context.divColor, height: 6),
              Text(AppLocalizations.of(context)!.destination, style: TextStyle(color: context.textSecondary, fontSize: 10, fontWeight: FontWeight.w400)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: context.primaryTint, borderRadius: BorderRadius.circular(6)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.directions_car_rounded, color: AppColors.primary, size: 12),
              const SizedBox(width: 4),
              Text(AppLocalizations.of(context)!.yourTrip, style: const TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildSheetContent(BuildContext context, SearchingState state, bool isDark) {
    if (state is SearchingInProgress) return _buildSearchingContent(context, state, isDark);
    if (state is SearchingSuccess) return _buildSuccessContent(context);
    if (state is SearchingNoDrivers) return _buildNoDriversContent(context);
    if (state is SearchingCancelled) return _buildCancelledContent(context);
    if (state is SearchingError) return _buildErrorContent(context, state.message);
    return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)));
  }

  Widget _buildSearchingContent(BuildContext context, SearchingInProgress state, bool isDark) {
    final minutes = state.remainingSeconds ~/ 60;
    final seconds = state.remainingSeconds % 60;
    final progress = 1.0 - (state.remainingSeconds / 180.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing radar animation + timer
        SizedBox(
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulse ring
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: _pulseAnim.value,
                  child: Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.12), width: 2),
                    ),
                  ),
                ),
              ),
              // Middle ring
              AnimatedBuilder(
                animation: _pulseAnim,
                builder: (_, __) => Transform.scale(
                  scale: 2 - _pulseAnim.value,
                  child: Container(
                    width: 85, height: 85,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.22), width: 2),
                    ),
                  ),
                ),
              ),
              // Center circle with timer
              Container(
                width: 68, height: 68,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [AppColors.primary, AppColors.primaryDark],
                  ),
                  boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 16, spreadRadius: 2)],
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(
                    '$minutes:${seconds.toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1),
                  ),
                  const SizedBox(height: 2),
                  Text(AppLocalizations.of(context)!.minute, style: const TextStyle(color: Colors.white60, fontSize: 9, fontWeight: FontWeight.w500)),
                ]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(AppLocalizations.of(context)!.searchingForDriver, style: TextStyle(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)!.willContactOnFind, style: TextStyle(color: context.textSecondary, fontSize: 12.5)),
        const SizedBox(height: 14),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: context.divColor,
            color: AppColors.primary,
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 48,
          child: OutlinedButton(
            onPressed: () => context.read<SearchingBloc>().add(CancelSearch(widget.tripId)),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.textSecondary,
              side: BorderSide(color: context.divColor),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(AppLocalizations.of(context)!.cancelSearch, style: TextStyle(color: context.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success.withValues(alpha: 0.1)),
          child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 36),
        ),
        const SizedBox(height: 12),
        Text(AppLocalizations.of(context)!.tripAccepted, style: TextStyle(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)!.loadingDriverDetails, style: TextStyle(color: context.textSecondary, fontSize: 13)),
        const SizedBox(height: 16),
        const LinearProgressIndicator(color: AppColors.success, backgroundColor: Colors.transparent),
      ],
    );
  }

  Widget _buildNoDriversContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.warning.withValues(alpha: 0.1)),
          child: const Icon(Icons.search_off_rounded, color: AppColors.warning, size: 32),
        ),
        const SizedBox(height: 12),
        Text(AppLocalizations.of(context)!.noDriversFound, style: TextStyle(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)!.tryAgainOrDifferentTime, style: TextStyle(color: context.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.go(AppRoutes.userHome),
              style: OutlinedButton.styleFrom(foregroundColor: context.textSecondary, side: BorderSide(color: context.divColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text(AppLocalizations.of(context)!.backToHome),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                context.read<SearchingBloc>().add(StartSearching(widget.tripId));
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ),
        ]),
      ],
    );
  }

  Widget _buildCancelledContent(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: context.divColor),
          child: Icon(Icons.cancel_rounded, color: context.textSecondary, size: 32),
        ),
        const SizedBox(height: 12),
        Text(AppLocalizations.of(context)!.searchCancelled, style: TextStyle(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)!.canSearchAnytime, style: TextStyle(color: context.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 48,
          child: ElevatedButton(
            onPressed: () => context.go(AppRoutes.userHome),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
            child: Text(AppLocalizations.of(context)!.backToHome, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent(BuildContext context, String message) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.warning.withValues(alpha: 0.1)),
          child: const Icon(Icons.person_off_rounded, color: AppColors.warning, size: 32),
        ),
        const SizedBox(height: 12),
        Text(AppLocalizations.of(context)!.noDriverAvailable, style: TextStyle(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(AppLocalizations.of(context)!.tryAgainLater, style: TextStyle(color: context.textSecondary, fontSize: 13), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.go(AppRoutes.userHome),
              style: OutlinedButton.styleFrom(foregroundColor: context.textSecondary, side: BorderSide(color: context.divColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text(AppLocalizations.of(context)!.backToHome),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.read<SearchingBloc>().add(StartSearching(widget.tripId)),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ),
        ]),
      ],
    );
  }
}


