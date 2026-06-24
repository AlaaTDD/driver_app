import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/map/app_map.dart';
import '../../../../core/models/trip_details_model.dart';
import '../../../../core/models/driver_info_model.dart';
import '../../../../core/constants/env_constants.dart';
import '../../../../core/services/directions_service.dart';
import '../trips/bloc/trips_bloc.dart';
import '../trips/bloc/trips_event.dart';
import '../trips/bloc/trips_state.dart';
import '../../../trips/presentation/bloc/trip_route_cubit.dart';
import '../../../../core/models/trip_route_waypoint_model.dart';
import 'package:geocoding/geocoding.dart';
import 'package:snapix/core/theme/app_colors.dart';
import '../../../../core/utils/map_camera_utils.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/utils/trip_status.dart';
import 'package:snapix/core/utils/app_logger.dart';
import 'package:snapix/features/trips/presentation/widgets/trip_widgets.dart';

// Shared widgets imported from trip_widgets barrel

// ─── Main Screen ──────────────────────────────────────────────────────────────
class UserTripDetailsScreen extends StatefulWidget {
  final String tripId;
  const UserTripDetailsScreen({super.key, required this.tripId});

  @override
  State<UserTripDetailsScreen> createState() => _ScreenState();
}

class _ScreenState extends State<UserTripDetailsScreen>
    with TickerProviderStateMixin {
  GoogleMapController? _mapCtrl;
  TripDetailsModel? _trip;

  // Route / polyline state
  List<LatLng> _routePoints = [];
  bool _routeFetchRequested = false;
  String _lastStopoversHash = '';
  final Map<String, BitmapDescriptor> _routeMarkerIcons = {};
  final Set<String> _pendingRouteMarkerIcons = {};
  String? _routeMarkerLocaleCode;
  bool _is3DMode = false;

  late AnimationController _sheetCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shimCtrl;

  late Animation<double> _sheetAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

  late TripRouteCubit _routeCubit;

  @override
  void initState() {
    super.initState();

    _sheetCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _shimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _sheetAnim = CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutExpo);
    _fadeAnim = CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOut);
    _pulseAnim = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _routeCubit = TripRouteCubit()..watchTripRoutes(widget.tripId);

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destIcon;
  BitmapDescriptor? _waypointIcon;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final localeCode = Localizations.localeOf(context).languageCode;
    if (_routeMarkerLocaleCode != localeCode) {
      _routeMarkerLocaleCode = localeCode;
      _routeMarkerIcons.clear();
      _pendingRouteMarkerIcons.clear();
    }
  }

  Future<void> _loadCircleIcons() async {
    _pickupIcon = await createCircleMarker(AppColors.success);
    _destIcon = await createCircleMarker(AppColors.error);
    _waypointIcon = await createCircleMarker(AppColors.warning);
    if (mounted) setState(() {});
  }

  void _load({bool silent = false}) {
    _loadCircleIcons();
    _animationTriggered = false;
    _routeFetchRequested = false;
    _routePoints = [];
    context
        .read<TripsBloc>()
        .add(LoadTripDetails(widget.tripId, silent: silent));
  }

  Future<void> _fetchRoute(double oLat, double oLng, double dLat, double dLng,
      [List<LatLng>? waypoints]) async {
    final result = await DirectionsService.getRoute(
      originLat: oLat,
      originLng: oLng,
      destLat: dLat,
      destLng: dLng,
      waypoints: waypoints,
      apiKey: EnvConstants.googleMapsApiKey,
    );
    if (!mounted || result == null) return;
    setState(() => _routePoints = result.points);
    // ✅ After fetching route, fit camera to full polyline
    _fitPolylineToBounds(result.points);
  }

  /// Fits the map camera so the full polyline is visible with padding.
  void _fitPolylineToBounds(List<LatLng> points) {
    final ctrl = _mapCtrl;
    if (ctrl == null || points.isEmpty) return;
    MapCameraUtils.fitCameraToPoints(
      ctrl,
      points,
      padding: 92,
      delay: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    _pulseCtrl.dispose();
    _shimCtrl.dispose();
    _mapCtrl?.dispose();
    _routeCubit.close();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  bool _animationTriggered = false;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: BlocConsumer<TripsBloc, TripsState>(
          listener: (ctx, state) {
            if (state is TripActionSuccess) {
              _toast(ctx, state.message, ok: true);
              // Defer the reload to the next frame.  Calling _load() (which
              // dispatches LoadTripDetails → emit TripDetailsLoading) synchronously
              // inside the listener causes a second widget-tree swap in the same
              // frame, dirtying semantics parentData and crashing with
              // `!semantics.parentDataDirty`.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _load(silent: true);
              });
            } else if (state is TripsError) {
              _toast(ctx, state.message, ok: false);
            } else if (state is TripDetailsLoaded) {
              // Trigger animation once after data loads (safe — runs after build)
              if (!_animationTriggered) {
                _animationTriggered = true;
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _sheetCtrl.forward(from: 0));
              }
            }
          },
          builder: (ctx, state) {
            if (state is TripsLoading || state is TripDetailsLoading)
              return _skeleton();
            if (state is TripDetailsLoaded) {
              _trip = state.trip;
              return _body(state.trip);
            }
            if (state is TripsError) return _errorView(state.message);
            // TripActionSuccess (and any other transient state) must NOT switch
            // to _skeleton().  Swapping _body() → _skeleton() while _pulseCtrl
            // and _shimCtrl are both repeating dirties semantics parentData in
            // the same frame, causing `!semantics.parentDataDirty` crash.
            // Keep showing the last known body using the cached _trip.
            if (_trip != null) return _body(_trip!);
            return _skeleton();
          },
        ),
      ),
    );
  }

  void _toast(BuildContext ctx, String msg, {required bool ok}) {
    if (ok) {
      AppToast.success(msg);
    } else {
      AppToast.error(msg);
    }
  }

  // ══════════════════════════════════════════════════════════
  // SKELETON
  // ══════════════════════════════════════════════════════════
  Widget _skeleton() {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _shimCtrl,
        builder: (_, __) {
          final t = (_shimCtrl.value * 2 - 1).abs();
          Color sh(Color b) => Color.lerp(b, context.elevatedColor, t)!;
          return Column(children: [
            Container(
                height: MediaQuery.of(context).size.height * 0.45,
                color: sh(context.cardColor)),
            Expanded(
              child: Container(
                color: context.cardColor,
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  const SizedBox(height: 8),
                  _sBox(sh, h: 28, w: 160),
                  const SizedBox(height: 24),
                  _sBox(sh, h: 72),
                  const SizedBox(height: 14),
                  _sBox(sh, h: 100),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _sBox(sh, h: 110)),
                    const SizedBox(width: 12),
                    Expanded(child: _sBox(sh, h: 110)),
                  ]),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _sBox(Color Function(Color) sh, {required double h, double? w}) =>
      Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
              color: sh(context.cardColor),
              borderRadius: BorderRadius.circular(14)));

  // ══════════════════════════════════════════════════════════
  // ERROR
  // ══════════════════════════════════════════════════════════
  Widget _errorView(String msg) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(
        child: Center(
            child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            color: AppColors.error.withValues(alpha: 0.08),
          ),
          child:
              Icon(Icons.cloud_off_rounded, size: 40, color: AppColors.error),
        ),
        const SizedBox(height: 24),
        Text(msg,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: context.textSecondary, fontSize: 14, height: 1.6)),
        const SizedBox(height: 32),
        TripActionButton(
            label: l.retry,
            icon: Icons.refresh_rounded,
            color: AppColors.primary,
            onTap: _load),
      ]),
    )));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN BODY — completely new layout
  // ══════════════════════════════════════════════════════════════════════════
  Widget _body(TripDetailsModel trip) {
    final status = trip.status;
    final driver = trip.driverData;
    final canCancel = TripStatus.fromString(status)?.isCancellable ?? false;
    final canTrack = {'accepted', 'in_progress'}.contains(status);
    final canComplain = {'completed', 'cancelled'}.contains(status);
    final canRate =
        status == 'completed' && trip.userRatingToDriver == null;
    final rated =
        status == 'completed' && trip.userRatingToDriver != null;

    final pLat = trip.pickupLat;
    final pLng = trip.pickupLng;

    final screenH = MediaQuery.of(context).size.height;
    final mapH = screenH * 0.44;

    return Stack(children: [
      // ── [1] Full-bleed map behind everything (rebuilds when waypoints change)
      Positioned.fill(
        child: BlocBuilder<TripRouteCubit, TripRouteState>(
          bloc: _routeCubit,
          builder: (context, routeState) {
            final stopovers =
                routeState.waypoints.where((w) => w.isStopover).toList();
            return (pLat != null && pLng != null && pLat != 0.0 && pLng != 0.0)
                ? _buildMap(trip, screenH - mapH, stopovers)
                : Container(
                    color: context.cardColor,
                    child: Center(
                        child: Icon(Icons.map_outlined,
                            color: context.textDisabled, size: 64)));
          },
        ),
      ),

      // ── [2] Header (Back, Status, Refresh)
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                MapCircleButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.pop()),
                Expanded(
                  child: Center(child: _statusPill(status)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MapCircleButton(
                      icon: _is3DMode ? Icons.view_in_ar : Icons.map_outlined,
                      onTap: () async {
                        final enabled = !_is3DMode;
                        setState(() => _is3DMode = enabled);
                        final ctrl = _mapCtrl;
                        if (ctrl == null || pLat == null || pLng == null) {
                          return;
                        }
                        final target = _routePoints.length > 2
                            ? _routePoints[_routePoints.length ~/ 2]
                            : LatLng(pLat, pLng);
                        await ctrl.animateCamera(
                          CameraUpdate.newCameraPosition(
                            CameraPosition(
                              target: target,
                              zoom: enabled ? 17.2 : 15,
                              tilt: enabled ? 48 : 0,
                              bearing: enabled ? _routeBearing() : 0,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    MapCircleButton(icon: Icons.refresh_rounded, onTap: _load),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),

      // ── [3.5] My Location button
      Positioned.directional(
        textDirection: Directionality.of(context),
        top: mapH - 70,
        end: 14,
        child: (pLat != null && pLng != null)
            ? MapCircleButton(
                icon: Icons.my_location_rounded,
                onTap: () {
                  if (_mapCtrl != null) {
                    _mapCtrl!.animateCamera(CameraUpdate.newCameraPosition(
                      CameraPosition(target: LatLng(pLat, pLng), zoom: 16),
                    ));
                  }
                },
              )
            : const SizedBox.shrink(),
      ),

      // ── [4] Bottom sheet slides up over map
      Positioned(
        top: mapH - 12,
        left: 0,
        right: 0,
        bottom: 0,
        child: SlideTransition(
          position:
              Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
                  .animate(_sheetAnim),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [
                // handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: context.divColor,
                      borderRadius: BorderRadius.circular(2)),
                ),

                // scrollable content
                Expanded(
                    child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Driver strip
                        if (driver != null) ...[
                          _DriverStrip(
                            driver: driver,
                            tripId: _trip?.id ?? '',
                            canTrack: canTrack,
                            onTrack: () => context.push(
                                '${AppRoutes.userTracking}?tripId=${_trip!.id}'),
                          ),
                          const SizedBox(height: 13),
                        ],

                        // ── Route section + stopovers ──────────────────────
                        BlocBuilder<TripRouteCubit, TripRouteState>(
                          bloc: _routeCubit,
                          builder: (context, routeState) {
                            final stopovers = routeState.waypoints
                                .where((w) => w.isStopover)
                                .toList();
                            final isEditable = [
                              'pending',
                              'searching',
                              'accepted',
                              'in_progress'
                            ].contains(trip.status);

                            return _StopoverCard(
                              trip: trip,
                              stopovers: stopovers,
                              isEditable: isEditable,
                              routeState: routeState,
                              onAddStop: () => _showAddStopoverDialog(context),
                              onRemoveStop: (id) =>
                                  _routeCubit.removeStopover(id),
                            );
                          },
                        ),
                        const SizedBox(height: 13),

                        // Price + stats (side by side, equal height)
                        IntrinsicHeight(
                            child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: TripPriceBox(trip: trip)),
                            const SizedBox(width: 12),
                            Expanded(child: TripStatsBox(trip: trip)),
                          ],
                        )),
                        const SizedBox(height: 13),

                        // Horizontal timeline
                        TripTimeline(trip: trip),
                        const SizedBox(height: 13),

                        // Rating badge
                        if (rated) _RatingBadge(trip: trip),

                        // Space for sticky action bar
                        SizedBox(
                            height: (canCancel || canRate || canComplain)
                                ? 90
                                : 20),
                      ]),
                )),
              ]),
            ),
          ),
        ),
      ),

      // ── [5] Sticky action bar pinned at bottom
      Positioned(
        left: 0,
        right: 0,
        bottom: 0,
        child: Offstage(
          offstage: !(canCancel || canRate || canComplain),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: _ActionBar(
              canCancel: canCancel,
              canRate: canRate,
              canComplain: canComplain,
              onCancel: () => _cancelDialog(trip.id),
              onRate: () =>
                  context.push('${AppRoutes.userRating}?tripId=${trip.id}'),
              onComplain: () => _complaintDialog(trip.id),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Map ────────────────────────────────────────────────────────────────────
  Widget _buildMap(TripDetailsModel trip, double bottomPadding,
      [List<TripRouteWaypointModel> stopovers = const []]) {
    final l = AppLocalizations.of(context)!;
    final pickupPoint = _tripPoint(trip.pickupLat, trip.pickupLng);
    final meetingPoint = _tripPoint(trip.meetingLat, trip.meetingLng);
    final destinationPoint =
        _tripPoint(trip.destinationLat, trip.destinationLng);
    if (pickupPoint == null) return const SizedBox.shrink();

    final separateMeetingPoint =
        meetingPoint != null && !_samePoint(meetingPoint, pickupPoint)
            ? meetingPoint
            : null;
    final routeStart = separateMeetingPoint ?? pickupPoint;
    final routeWaypoints = <LatLng>[
      if (separateMeetingPoint != null) pickupPoint,
      ...stopovers.map((w) => LatLng(w.lat, w.lng)),
    ];

    final markers = <Marker>{
      if (separateMeetingPoint != null)
        Marker(
          markerId: const MarkerId('meeting'),
          position: separateMeetingPoint,
          icon: _routeMarkerIcon(
            cacheKey: 'meeting',
            label: l.meetingPointLabel,
            color: AppColors.primary,
            fallback: _pickupIcon,
            icon: Icons.groups_rounded,
          ),
          anchor: const Offset(0.5, 0.78),
          zIndex: 4,
          infoWindow: InfoWindow(title: l.meetingPointLabel),
        ),
      Marker(
        markerId: const MarkerId('p'),
        position: pickupPoint,
        icon: _routeMarkerIcon(
          cacheKey: 'pickup',
          label: l.pickupPoint,
          color: AppColors.success,
          fallback: _pickupIcon,
          icon: Icons.trip_origin_rounded,
        ),
        anchor: const Offset(0.5, 0.78),
        zIndex: 3,
        infoWindow: InfoWindow(title: l.pickupPoint),
      ),
      if (destinationPoint != null)
        Marker(
          markerId: const MarkerId('d'),
          position: destinationPoint,
          icon: _routeMarkerIcon(
            cacheKey: 'destination',
            label: l.destination,
            color: AppColors.error,
            fallback: _destIcon,
            icon: Icons.flag_rounded,
          ),
          anchor: const Offset(0.5, 0.78),
          zIndex: 3,
          infoWindow: InfoWindow(title: l.destination),
        ),
    };
    // ── Waypoint / Stopover markers ──
    for (int i = 0; i < stopovers.length; i++) {
      final wp = stopovers[i];
      final label = l.stopoverNumber(i + 1);
      markers.add(Marker(
        markerId: MarkerId('wp_$i'),
        position: LatLng(wp.lat, wp.lng),
        icon: _routeMarkerIcon(
          cacheKey: 'stopover_$i',
          label: label,
          color: AppColors.warning,
          fallback: _waypointIcon,
          icon: Icons.location_on_rounded,
        ),
        anchor: const Offset(0.5, 0.78),
        zIndex: 2,
        infoWindow: InfoWindow(title: wp.address ?? label),
      ));
    }

    // Fetch route once or when route points change.
    if (destinationPoint != null) {
      final routeHash = [
        routeStart,
        ...routeWaypoints,
        destinationPoint,
      ]
          .map((p) =>
              '${p.latitude.toStringAsFixed(5)},${p.longitude.toStringAsFixed(5)}')
          .join('|');
      if (!_routeFetchRequested || _lastStopoversHash != routeHash) {
        _routeFetchRequested = true;
        _lastStopoversHash = routeHash;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _fetchRoute(
            routeStart.latitude,
            routeStart.longitude,
            destinationPoint.latitude,
            destinationPoint.longitude,
            routeWaypoints,
          ),
        );
      }
    }

    final polylines = <Polyline>{};
    if (_routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route_bg'),
        points: _routePoints,
        color: AppColors.primary.withValues(alpha: 0.25),
        width: 12,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 0,
      ));
      polylines.add(Polyline(
        polylineId: const PolylineId('route_fg'),
        points: _routePoints,
        color: AppColors.primary,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ));
    }

    return Stack(fit: StackFit.expand, children: [
      AppGoogleMap(
        initialCameraPosition: CameraPosition(
          target: pickupPoint,
          zoom: _is3DMode ? 17.2 : 15,
          tilt: _is3DMode ? 48 : 0,
          bearing: _is3DMode ? _routeBearing() : 0,
        ),
        mapStyle: AppMapStyle.auto,
        buildingsEnabled: false,
        minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 60,
          bottom: bottomPadding + 20,
        ),
        onMapCreated: (ctrl) {
          _mapCtrl = ctrl;
          // Initial fit to markers; polyline fit happens after route loads
          final allPts = [
            pickupPoint,
            if (separateMeetingPoint != null) separateMeetingPoint,
            if (destinationPoint != null) destinationPoint,
            ...stopovers.map((w) => LatLng(w.lat, w.lng)),
          ].where((p) => p.latitude != 0.0 && p.longitude != 0.0).toList();
          if (allPts.isNotEmpty) {
            MapCameraUtils.fitCameraToPoints(
              ctrl,
              allPts,
              padding: 92,
              delay: const Duration(milliseconds: 500),
            );
          }
          // If polyline already loaded (screen revisit), re-fit to it immediately
          if (_routePoints.length >= 2) {
            Future.delayed(const Duration(milliseconds: 600),
                () => _fitPolylineToBounds(_routePoints));
          }
        },
        markers: markers,
        polylines: polylines,
      ),
      // fade to bg at bottom
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        height: 80,
        child: DecoratedBox(
            decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.transparent,
              context.bgColor.withValues(alpha: 0.88)
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        )),
      ),
    ]);
  }

  LatLng? _tripPoint(double? lat, double? lng) {
    if (lat == null || lng == null) return null;
    if (lat == 0.0 && lng == 0.0) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    return LatLng(lat, lng);
  }

  bool _samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00005 &&
        (a.longitude - b.longitude).abs() < 0.00005;
  }

  double _routeBearing() {
    if (_routePoints.length < 2) return 0;
    final start = _routePoints.first;
    final end = _routePoints.last;
    return AppMapBearing.calculate(start, end);
  }

  BitmapDescriptor _routeMarkerIcon({
    required String cacheKey,
    required String label,
    required Color color,
    required IconData icon,
    BitmapDescriptor? fallback,
  }) {
    final key = '${_routeMarkerLocaleCode ?? ''}|$cacheKey|$label';
    final cached = _routeMarkerIcons[key];
    if (cached != null) return cached;
    if (!_pendingRouteMarkerIcons.contains(key)) {
      _pendingRouteMarkerIcons.add(key);
      AppMapMarkerFactory.labeledPin(
        label: label,
        color: color,
        icon: icon,
        textDirection: Directionality.of(context),
      ).then((descriptor) {
        if (!mounted) return;
        setState(() {
          _routeMarkerIcons[key] = descriptor;
          _pendingRouteMarkerIcons.remove(key);
        });
      });
    }
    return fallback ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
  }

  // ── Status pill ────────────────────────────────────────────────────────────
  Widget _statusPill(String? status) {
    final color = _statusColor(status);
    final icon = _statusIcon(status);
    final label = _statusLabel(status);
    final live = status == 'in_progress' || status == 'searching';

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, child) => Transform.scale(
            scale: live ? (0.97 + 0.03 * _pulseAnim.value) : 1.0,
            child: child,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
            decoration: BoxDecoration(
              color: context.cardColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(32),
              border:
                  Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 22,
                    spreadRadius: 2),
                BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.54),
                    blurRadius: 10),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (live)
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: _pulseAnim.value),
                            blurRadius: 8)
                      ],
                    ),
                  ),
                )
              else
                Icon(icon, color: color, size: 16),
              const SizedBox(width: 9),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2)),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _cancelDialog(String tripId) {
    final l = AppLocalizations.of(context)!;
    final bloc = context.read<TripsBloc>();
    showDialog(
      context: context,
      builder: (dialogCtx) => TripNightDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: AppColors.error,
        title: l.cancelTrip,
        body: l.areYouSureCancelTrip,
        confirmLabel: l.yesCancel,
        confirmColor: AppColors.error,
        cancelLabel: l.noLabel,
        onConfirm: () {
          Navigator.of(dialogCtx).pop();
          bloc.add(CancelUserTrip(tripId));
        },
      ),
    );
  }

  void _complaintDialog(String tripId) {
    final l = AppLocalizations.of(context)!;
    final tCtrl = TextEditingController();
    final dCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final bloc = context.read<TripsBloc>();
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(Icons.report_problem_rounded,
                      color: AppColors.primary, size: 20)),
              const SizedBox(width: 14),
              Text(l.submitComplaint,
                  style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 20),
            Form(
                key: formKey,
                child: Column(children: [
                  TripNightField(
                      ctrl: tCtrl,
                      label: l.complaintSubject,
                      hint: l.complaintSubjectHint,
                      icon: Icons.subject_rounded,
                      validator: (v) =>
                          v!.isEmpty ? l.complaintSubjectHint : null),
                  const SizedBox(height: 12),
                  TripNightField(
                      ctrl: dCtrl,
                      label: l.complaintDetails,
                      hint: l.complaintDetailsHint,
                      icon: Icons.description_rounded,
                      maxLines: 3,
                      validator: (v) =>
                          v!.isEmpty ? l.complaintDetailsHint : null),
                ])),
            const SizedBox(height: 20),
            Row(children: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(l.cancel,
                    style: TextStyle(
                        color: context.textSecondary,
                        fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              TripActionButton(
                  label: l.send,
                  icon: Icons.send_rounded,
                  color: AppColors.primary,
                  compact: true,
                  onTap: () {
                    if (formKey.currentState?.validate() == true) {
                      Navigator.of(dialogCtx).pop();
                      bloc.add(SubmitTripComplaint(
                          tripId: tripId,
                          title: tCtrl.text,
                          description: dCtrl.text));
                    }
                  }),
            ]),
          ]),
        ),
      ),
    );
  }

  void _showAddStopoverDialog(BuildContext context) {
    final pLat = _trip?.pickupLat ?? 0.0;
    final pLng = _trip?.pickupLng ?? 0.0;
    final dLat = _trip?.destinationLat;
    final dLng = _trip?.destinationLng;

    if (pLat == 0.0 || pLng == 0.0) return;

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MapStopoverPicker(
            initialCenter: LatLng(pLat, pLng),
            originPoint: LatLng(pLat, pLng), // ✅ show pickup
            destPoint: (dLat != null && dLng != null)
                ? LatLng(dLat, dLng)
                : null, // ✅ show destination
          ),
        )).then((result) {
      if (result != null && result is Map<String, dynamic>) {
        _routeCubit.addStopover(
          lat: result['lat'],
          lng: result['lng'],
          address: result['address'],
        );
      }
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _statusColor(String? s) => switch (s) {
        'completed' => AppColors.success,
        'cancelled' => AppColors.error,
        'in_progress' || 'accepted' => AppColors.primary,
        'searching' => AppColors.warning,
        _ => context.textSecondary,
      };

  IconData _statusIcon(String? s) => switch (s) {
        'completed' => Icons.check_circle_rounded,
        'cancelled' => Icons.cancel_rounded,
        'in_progress' => Icons.local_taxi_rounded,
        'accepted' => Icons.thumb_up_rounded,
        'searching' => Icons.radar_rounded,
        _ => Icons.help_outline_rounded,
      };

  String _statusLabel(String? s) {
    final l = AppLocalizations.of(context)!;
    return switch (s) {
      'completed' => l.completed,
      'cancelled' => l.cancelled,
      'in_progress' => l.inProgress,
      'accepted' => l.tripAccepted,
      'searching' => l.searchingForDriver,
      _ => l.pending,
    };
  }
}




// ── Driver strip (compact horizontal) ────────────────────────────────────────
class _DriverStrip extends StatelessWidget {
  final DriverInfoModel driver;
  final String tripId;
  final bool canTrack;
  final VoidCallback onTrack;
  const _DriverStrip({
    required this.driver,
    required this.tripId,
    required this.canTrack,
    required this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = driver.name.isNotEmpty ? driver.name : l.theDriver;
    final avatarUrl = driver.avatarUrl;
    final rating = driver.rating?.toStringAsFixed(1) ?? '0.0';
    final plate = driver.vehiclePlate ?? '';
    final driverId = driver.id;
    final phone = driver.phone;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Row(children: [
        // Avatar + online dot
        Stack(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: context.elevatedColor,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800))
                  : null,
            ),
          ),
          Positioned(
            bottom: 1,
            right: 1,
            child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.cardColor, width: 2),
                )),
          ),
        ]),
        const SizedBox(width: 12),

        // Name + meta
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.star_rounded, color: AppColors.warning, size: 13),
            const SizedBox(width: 3),
            Text(rating,
                style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            if (plate.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.elevatedColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.divColor),
                ),
                child: Text(plate,
                    style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2)),
              ),
            ],
          ]),
        ])),

        // Action icons
        Row(children: [
          _CircleAction(
              icon: Icons.chat_bubble_rounded,
              color: AppColors.primary,
              onTap: () {
                if (tripId.isNotEmpty &&
                    driverId.isNotEmpty) {
                  context.push(
                      '${AppRoutes.userMessages}?tripId=$tripId&otherUserId=$driverId&otherUserName=${Uri.encodeComponent(name)}');
                } else {
                  context.push(AppRoutes.userMessages);
                }
              }),
          if (phone != null) ...[
            const SizedBox(width: 8),
            _CircleAction(
                icon: Icons.phone_rounded,
                color: AppColors.success,
                onTap: () {}),
          ],
          if (canTrack) ...[
            const SizedBox(width: 8),
            _CircleAction(
                icon: Icons.my_location_rounded,
                color: AppColors.warning,
                onTap: onTrack),
          ],
        ]),
      ]),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleAction(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
          ),
          child: Icon(icon, color: color, size: 17),
        ),
      );
}

// ── Stopover Card (unified route + stop management UI) ────────────────────────
class _StopoverCard extends StatelessWidget {
  final TripDetailsModel trip;
  final List<TripRouteWaypointModel> stopovers;
  final bool isEditable;
  final TripRouteState routeState;
  final VoidCallback onAddStop;
  final void Function(String id) onRemoveStop;

  const _StopoverCard({
    required this.trip,
    required this.stopovers,
    required this.isEditable,
    required this.routeState,
    required this.onAddStop,
    required this.onRemoveStop,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final pickup = trip.pickupAddress ?? '';
    final dest = trip.destinationAddress ?? '';
    final hasStops = stopovers.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.divColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ─────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.alt_route_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(l.tripRoute,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: context.textPrimary)),
              const Spacer(),
              if (hasStops)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Text(l.stopCount(stopovers.length),
                      style: TextStyle(
                          fontSize: 10,
                          color: AppColors.warning,
                          fontWeight: FontWeight.w700)),
                ),
            ]),
          ),

          const SizedBox(height: 14),

          // ── Route spine ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              // Origin row
              _SpineRow(
                dot: _SpineDot(
                    color: AppColors.success, icon: Icons.trip_origin_rounded),
                label: pickup.isNotEmpty ? pickup : l.pickupPoint,
                isFirst: true,
              ),

              // Stopovers
              ...List.generate(stopovers.length, (i) {
                final wp = stopovers[i];
                return _SpineRow(
                  dot: _SpineDot(
                    color: AppColors.warning,
                    icon: Icons.radio_button_checked_rounded,
                    index: i + 1,
                  ),
                  label: wp.address ?? l.stopoverNumber(i + 1),
                  isFirst: false,
                  trailing: isEditable
                      ? GestureDetector(
                          onTap: () => onRemoveStop(wp.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color:
                                      AppColors.error.withValues(alpha: 0.25)),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.remove_circle_outline_rounded,
                                  color: AppColors.error, size: 13),
                              const SizedBox(width: 4),
                              Text(l.delete,
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: AppColors.error,
                                      fontWeight: FontWeight.w700)),
                            ]),
                          ),
                        )
                      : null,
                );
              }),

              // Destination row
              _SpineRow(
                dot: _SpineDot(
                    color: AppColors.error, icon: Icons.location_on_rounded),
                label: dest.isNotEmpty ? dest : l.destination,
                isFirst: false,
                isLast: true,
              ),
            ]),
          ),

          // ── Add stop row (only when editable) ──────────────────────────────
          if (isEditable) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Divider(color: context.divColor, height: 1),
            ),
            Material(
              color: AppColors.transparent,
              child: InkWell(
                onTap: onAddStop,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(22)),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25)),
                      ),
                      child: Icon(Icons.add_location_alt_rounded,
                          color: AppColors.primary, size: 15),
                    ),
                    const SizedBox(width: 10),
                    Text(l.addStopover,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Icon(Icons.chevron_right_rounded,
                        color: context.textDisabled, size: 18),
                  ]),
                ),
              ),
            ),
          ] else
            const SizedBox(height: 14),
        ],
      ),
    );
  }
}

class _SpineDot extends StatelessWidget {
  final Color color;
  final IconData icon;
  final int? index;
  const _SpineDot({required this.color, required this.icon, this.index});

  @override
  Widget build(BuildContext context) {
    return Stack(alignment: Alignment.center, children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
        ),
        child: index != null
            ? Center(
                child: Text('$index',
                    style: TextStyle(
                        fontSize: 9,
                        color: color,
                        fontWeight: FontWeight.w900)))
            : Icon(icon, color: color, size: 13),
      ),
    ]);
  }
}

class _SpineRow extends StatelessWidget {
  final _SpineDot dot;
  final String label;
  final bool isFirst;
  final bool isLast;
  final Widget? trailing;

  const _SpineRow({
    required this.dot,
    required this.label,
    required this.isFirst,
    this.isLast = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Spine column
        SizedBox(
            width: 28,
            child: Column(children: [
              if (!isFirst)
                Expanded(
                    child: Center(
                        child: Container(width: 1.5, color: context.divColor))),
              dot,
              if (!isLast)
                Expanded(
                    child: Center(
                        child: Container(width: 1.5, color: context.divColor))),
              if (isLast) const SizedBox(height: 4),
            ])),
        const SizedBox(width: 10),
        // Label
        Expanded(
            child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            Expanded(
                child: Text(label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isFirst
                          ? context.textPrimary
                          : isLast
                              ? context.textPrimary
                              : context.textSecondary,
                      fontWeight:
                          isFirst || isLast ? FontWeight.w600 : FontWeight.w400,
                    ))),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ]),
        )),
      ]),
    );
  }
}

// ── Rating Badge ──────────────────────────────────────────────────────────────
class _RatingBadge extends StatelessWidget {
  final TripDetailsModel trip;
  const _RatingBadge({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.success.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(children: [
        const Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(l.tripRated,
                style: TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w700))),
        const Icon(Icons.star_rounded, color: AppColors.warning, size: 18),
        const SizedBox(width: 4),
        Text(trip.userRatingToDriver?.toString() ?? '',
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
      ]),
    );
  }
}

// ── Sticky action bar ─────────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final bool canCancel, canRate, canComplain;
  final VoidCallback onCancel, onRate, onComplain;
  const _ActionBar({
    required this.canCancel,
    required this.canRate,
    required this.canComplain,
    required this.onCancel,
    required this.onRate,
    required this.onComplain,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final l = AppLocalizations.of(context)!;

    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + bottom),
      decoration: BoxDecoration(
        color: context.cardColor,
        border: Border(top: BorderSide(color: context.divColor, width: 1)),
        boxShadow: [
          BoxShadow(
              color: AppColors.black.withValues(alpha: 0.45),
              blurRadius: 20,
              offset: Offset(0, -4))
        ],
      ),
      child: Row(children: [
        if (canCancel) ...[
          Expanded(
              child: TripActionButton(
                  label: l.cancelTrip,
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                  outlined: true,
                  onTap: onCancel)),
          if (canRate || canComplain) const SizedBox(width: 10),
        ],
        if (canRate) ...[
          Expanded(
              child: TripActionButton(
                  label: l.rateTrip,
                  icon: Icons.star_rounded,
                  color: AppColors.warning,
                  onTap: onRate)),
          if (canComplain) const SizedBox(width: 10),
        ],
        if (canComplain)
          Expanded(
              child: TripActionButton(
                  label: l.complaints,
                  icon: Icons.report_problem_outlined,
                  color: AppColors.primary,
                  outlined: true,
                  onTap: onComplain)),
      ]),
    );
  }
}

// ── Reusable button ───────────────────────────────────────────────────────────
class MapStopoverPicker extends StatefulWidget {
  final LatLng initialCenter;
  final LatLng? originPoint; // optional: show pickup marker for context
  final LatLng? destPoint; // optional: show destination marker for context
  const MapStopoverPicker({
    super.key,
    required this.initialCenter,
    this.originPoint,
    this.destPoint,
  });

  @override
  State<MapStopoverPicker> createState() => _MapStopoverPickerState();
}

class _MapStopoverPickerState extends State<MapStopoverPicker> {
  LatLng? _selectedPoint;
  String? _resolvedAddress;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: MapCircleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ),
      body: Stack(children: [
        AppGoogleMap(
          initialCameraPosition:
              CameraPosition(target: widget.initialCenter, zoom: 15),
          onTap: (latLng) async {
            setState(() {
              _selectedPoint = latLng;
              _isLoading = true;
            });
            try {
              final placemarks = await placemarkFromCoordinates(
                  latLng.latitude, latLng.longitude);
              if (placemarks.isNotEmpty) {
                final p = placemarks.first;
                setState(() => _resolvedAddress = '${p.street}, ${p.locality}');
              }
            } catch (e) {
              setState(() => _resolvedAddress =
                  '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}');
            } finally {
              setState(() => _isLoading = false);
            }
          },
          markers: {
            // Context: origin marker (green)
            if (widget.originPoint != null)
              Marker(
                markerId: const MarkerId('ctx_origin'),
                position: widget.originPoint!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
                infoWindow: InfoWindow(title: l.pickupPoint),
              ),
            // Context: destination marker (red)
            if (widget.destPoint != null)
              Marker(
                markerId: const MarkerId('ctx_dest'),
                position: widget.destPoint!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed),
                infoWindow: InfoWindow(title: l.destination),
              ),
            // Selected stop marker (orange)
            if (_selectedPoint != null)
              Marker(
                markerId: const MarkerId('selected'),
                position: _selectedPoint!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueOrange),
                infoWindow:
                    InfoWindow(title: _resolvedAddress ?? l.selectedStopover),
              ),
          },
        ),
        if (_selectedPoint != null)
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.26),
                      blurRadius: 10)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.confirmStopover,
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (_isLoading)
                    const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary))
                  else
                    Text(
                      _resolvedAddress ?? l.loading,
                      style:
                          TextStyle(color: context.textSecondary, fontSize: 14),
                    ),
                  const SizedBox(height: 16),
                  AppButton(
                    text: l.addThisStopover,
                    isLoading: _isLoading,
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.pop(context, {
                              'lat': _selectedPoint!.latitude,
                              'lng': _selectedPoint!.longitude,
                              'address': _resolvedAddress,
                            });
                          },
                  ),
                ],
              ),
            ),
          ),
      ]),
    );
  }
}
