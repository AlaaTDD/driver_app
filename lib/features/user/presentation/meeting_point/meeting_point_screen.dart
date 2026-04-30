// lib/features/user/presentation/meeting_point/meeting_point_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'bloc/meeting_bloc.dart';
import 'bloc/meeting_event.dart';
import 'bloc/meeting_state.dart';
import 'meeting_point_args.dart';
import '../location_selection/location_selection_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/geohash_helper.dart';
import 'data/meeting_point_repository.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../../core/localization/generated/app_localizations.dart';

class MeetingPointScreen extends StatefulWidget {
  final MeetingPointArgs? extra;

  const MeetingPointScreen({super.key, required this.extra});

  @override
  State<MeetingPointScreen> createState() => _MeetingPointScreenState();
}

class _MeetingPointScreenState extends State<MeetingPointScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  bool _isCreatingTrip = false;
  Timer? _geocodeDebounce;
  final _repository = MeetingPointRepository();

  static const double _sheetHeight = 220;

  @override
  void initState() {
    super.initState();
    final args = widget.extra;
    if (args?.originLat != null) {
      // Initialize meeting point to origin so map shows a marker immediately
      context.read<MeetingBloc>().add(SelectMeetingPoint(
        args!.originLat!, args.originLng!,
        args.originAddress?.isNotEmpty == true ? args.originAddress! : AppLocalizations.of(context)!.startingPoint,
      ));
      Future.delayed(Duration.zero, () async {
        if (!_mapController.isCompleted) return;
        final ctrl = await _mapController.future;
        ctrl.animateCamera(CameraUpdate.newLatLngZoom(
          LatLng(args.originLat!, args.originLng!), 15,
        ));
      });
    }
  }

  Future<void> _onMapTap(LatLng pos) async {
    // FIX M08: Cancel pending geocode and debounce rapid taps
    _geocodeDebounce?.cancel();
    _geocodeDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
        final place = placemarks.isNotEmpty ? placemarks.first : null;
        final parts = place != null
            ? [place.street, place.subLocality, place.locality]
                .where((e) => e != null && e.isNotEmpty).cast<String>().toList()
            : <String>[];
        final address = parts.isNotEmpty
            ? parts.join(', ')
            : '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        if (!mounted) return;
        context.read<MeetingBloc>().add(
              SelectMeetingPoint(pos.latitude, pos.longitude, address),
            );
      } catch (e) { debugPrint('❌ Error: $e'); }
    });
  }

  Future<void> _startSearch() async {
    final args = widget.extra;
    if (args == null) return;

    // Get the dynamically selected meeting point from the bloc
    final meetingState = context.read<MeetingBloc>().state;
    final finalLat = meetingState.meetingLat ?? args.originLat;
    final finalLng = meetingState.meetingLng ?? args.originLng;
    final finalAddress = meetingState.meetingAddress ?? args.originAddress;

    // Validate required coordinates before hitting the DB
    if (finalLat == null || finalLng == null || args.destLat == null) {
      AppToast.error(AppLocalizations.of(context)!.tripDataIncomplete);
      return;
    }

    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) {
      AppToast.error(AppLocalizations.of(context)!.pleaseLogin);
      return;
    }

    // Cache localizations before async gaps to avoid use_build_context_synchronously
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isCreatingTrip = true);
    try {
      final vehicleType = (args.vehicleType?.isNotEmpty ?? false) ? args.vehicleType! : 'sedan';
      debugPrint('🚗 MeetingPoint: inserting trip with vehicle_type=$vehicleType');

      // 1. Check if user already has an active trip
      final hasActive = await _repository.hasActiveTrip(authState.user.id);

      if (hasActive) {
        if (mounted) {
          AppToast.error(AppLocalizations.of(context)!.errorActiveTripExists);
          setState(() => _isCreatingTrip = false);
        }
        return;
      }

      // 2. Build the trip data using the final meeting point
      final tripData = <String, dynamic>{
        'user_id': authState.user.id,
        'pickup_lat': finalLat,
        'pickup_lng': finalLng,
        'pickup_address': (finalAddress?.isNotEmpty == true)
            ? finalAddress!
            : l10n.unspecified,
        'destination_lat': args.destLat,
        'destination_lng': args.destLng,
        'destination_address': (args.destAddress?.isNotEmpty == true)
            ? args.destAddress!
            : l10n.unspecified,
        'distance_km': args.distanceKm ?? 0.0,
        'price': args.price ?? 0.0,
        'vehicle_type': vehicleType,
        'payment_method': args.paymentMethod ?? 'cash',
        'status': 'searching',
      };

      // 3. Add geohash for spatial indexing (column must exist in schema)
      try {
        final geohash = GeohashHelper.encode(finalLat, finalLng);
        tripData['geohash'] = geohash;
      } catch (e) {
        debugPrint('⚠️ Failed to encode geohash: $e');
      }

      // 4. Insert the trip with retry via repository
      final result = await _repository.createTrip(
        userId: authState.user.id,
        pickupLat: finalLat,
        pickupLng: finalLng,
        pickupAddress: (finalAddress?.isNotEmpty == true) ? finalAddress! : l10n.unspecified,
        destLat: args.destLat ?? 0.0,
        destLng: args.destLng ?? 0.0,
        destAddress: (args.destAddress?.isNotEmpty == true) ? args.destAddress! : l10n.unspecified,
        distanceKm: args.distanceKm ?? 0.0,
        price: args.price ?? 0.0,
        vehicleType: vehicleType,
        paymentMethod: args.paymentMethod ?? 'cash',
        geohash: tripData['geohash'] as String?,
        couponCode: args.couponCode,
      );

      if (!mounted) return;
      final oParams = '&oLat=$finalLat&oLng=$finalLng';
      final dParams = '&dLat=${args.destLat}&dLng=${args.destLng}';
      context.go('${AppRoutes.userSearching}?tripId=${result['id']}$oParams$dParams');
    } catch (e) {
      debugPrint('❌ Trip insert error: $e');
      if (mounted) AppToast.error('${AppLocalizations.of(context)!.failedCreateTrip}: $e');
    } finally {
      if (mounted) setState(() => _isCreatingTrip = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final args = widget.extra;
    final originLatLng = args?.originLat != null
        ? LatLng(args!.originLat!, args.originLng!)
        : AppConstants.defaultMapCenter;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // ── Full-screen map ────────────────────────────────────────────────
          Positioned.fill(
            child: BlocBuilder<MeetingBloc, MeetingState>(
              builder: (context, state) => _buildMap(
                isDark, originLatLng, args, state,
              ),
            ),
          ),

          // ── Floating back button ───────────────────────────────────────────
          Positioned(
            top: 0, left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1526) : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 4)),
                        BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1)),
                      ],
                    ),
                    child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.textPrimary),
                  ),
                ),
              ),
            ),
          ),

          // ── Floating title badge ───────────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0D1526) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 10, offset: const Offset(0, 3))],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.place_rounded, color: AppColors.primary, size: 14),
                      const SizedBox(width: 5),
                      Text(AppLocalizations.of(context)!.meetingPoint, style: TextStyle(color: context.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
                    ]),
                  ),
                ),
              ),
            ),
          ),

          // ── Tap hint badge ─────────────────────────────────────────────────
          Positioned(
            bottom: _sheetHeight + 16, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withValues(alpha: 0.55) : Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.touch_app_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(AppLocalizations.of(context)!.tapMapToSelect, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),

          // ── Bottom sheet ───────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: BlocBuilder<MeetingBloc, MeetingState>(
              builder: (context, state) => _buildBottomSheet(context, state, isDark, args),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark, LatLng origin, MeetingPointArgs? args, MeetingState state) {
    // Only show the meeting point marker — no origin/destination clutter
    final markers = <Marker>{};
    if (state.meetingLat != null) {
      markers.add(Marker(
        markerId: const MarkerId('meeting'),
        position: LatLng(state.meetingLat!, state.meetingLng!),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(title: state.meetingAddress ?? AppLocalizations.of(context)!.meetingPoint),
      ));
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: origin, zoom: 15),
      onMapCreated: (ctrl) { if (!_mapController.isCompleted) _mapController.complete(ctrl); },
      onTap: _onMapTap,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: markers,
      style: isDark ? kDarkMapStyle : kLightMapStyle,
      padding: EdgeInsets.only(bottom: _sheetHeight, top: 80),
    );
  }

  Widget _buildBottomSheet(BuildContext context, MeetingState state, bool isDark, MeetingPointArgs? args) {
    return Container(
      constraints: const BoxConstraints(maxHeight: _sheetHeight),
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
            margin: const EdgeInsets.only(top: 12, bottom: 14),
            decoration: BoxDecoration(color: context.divColor, borderRadius: BorderRadius.circular(100)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Meeting point badge ────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 0.8),
                  ),
                  child: Row(children: [
                    const Icon(Icons.place_rounded, color: AppColors.primary, size: 15),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        state.meetingAddress ?? args?.originAddress ?? AppLocalizations.of(context)!.startingPoint,
                        style: const TextStyle(color: AppColors.primary, fontSize: 12.5, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 6),
                // ── Reset to origin link ────────────────────────────────────
                GestureDetector(
                  onTap: () {
                    final a = widget.extra;
                    if (a?.originLat != null) {
                      context.read<MeetingBloc>().add(SelectMeetingPoint(
                        a!.originLat!, a.originLng!,
                        a.originAddress?.isNotEmpty == true ? a.originAddress! : AppLocalizations.of(context)!.startingPoint,
                      ));
                      _mapController.future.then((ctrl) => ctrl.animateCamera(
                        CameraUpdate.newLatLngZoom(LatLng(a.originLat!, a.originLng!), 15),
                      ));
                    }
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.my_location_rounded, size: 12, color: context.textSecondary),
                      const SizedBox(width: 4),
                      Text(AppLocalizations.of(context)!.resetToOrigin, style: TextStyle(color: context.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // ── Price row + search button ───────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(AppLocalizations.of(context)!.price, style: TextStyle(color: context.textSecondary, fontSize: 11)),
                        Text('${args?.price?.toStringAsFixed(2) ?? '0'} ${AppLocalizations.of(context)!.currencySar}', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800, fontSize: 17)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isCreatingTrip ? null : _startSearch,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 6, shadowColor: AppColors.primary.withValues(alpha: 0.4),
                          ),
                          child: _isCreatingTrip
                              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                              : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  const Icon(Icons.search_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Text(AppLocalizations.of(context)!.searchForDriver, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
