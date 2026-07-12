import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bloc/tracking_bloc.dart';
import 'bloc/tracking_event.dart';
import 'bloc/tracking_state.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/env_constants.dart';
import 'package:flutter/scheduler.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/map/app_map.dart';
import '../../../../core/models/trip_route_waypoint_model.dart';
import '../../../trips/presentation/bloc/trip_route_cubit.dart';
import 'package:snapix/core/theme/app_colors.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import '../../../../core/utils/map_camera_utils.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/services/directions_service.dart';
import 'package:snapix/core/utils/app_logger.dart';

class TripTrackingScreen extends StatefulWidget {
  final String tripId;
  const TripTrackingScreen({super.key, required this.tripId});

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen>
    with SingleTickerProviderStateMixin {
  GoogleMapController? _mapController;
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destIcon;
  BitmapDescriptor? _waypointIcon;

  late TripRouteCubit _routeCubit;

  // ─── Smooth interpolation (no AnimationController, no setState) ───────────
  final ValueNotifier<Marker?> _driverMarkerNotifier = ValueNotifier(null);
  LatLng? _targetDriverPosition;
  LatLng? _animatedDriverPosition;
  double _driverRotation = 0.0;
  Ticker? _animationTicker;
  bool _is3DMode = false;
  String? _lastRouteBoundsSignature;
  CameraPosition? _lastCameraPosition;
  List<LatLng> _driverApproachRoutePoints = const [];
  String? _lastDriverApproachRouteHash;
  DateTime? _lastDriverApproachRouteRequestAt;
  bool _driverApproachRouteLoading = false;
  String? _completedDriverApproachTargetHash;
  final Map<String, BitmapDescriptor> _routeMarkerIcons = {};
  final Set<String> _pendingRouteMarkerIcons = {};
  String? _routeMarkerLocaleCode;

  static CameraPosition get _defaultCamera => CameraPosition(
        target: AppConstants.defaultMapCenter,
        zoom: 14,
      );

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _loadCircleIcons();
    _startAnimationLoop();
    _routeCubit = TripRouteCubit()..watchTripRoutes(widget.tripId);
    context.read<TrackingBloc>().add(LoadTripTracking(widget.tripId));
  }

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
    _pickupIcon = await _createCircleMarker(AppColors.success);
    _destIcon = await _createCircleMarker(AppColors.error);
    _waypointIcon = await _createCircleMarker(AppColors.warning);
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createCircleMarker(Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;

    // Draw outer circle with opacity (reduced glow)
    final outerPaint = Paint()..color = color.withOpacity(0.2);
    canvas.drawCircle(const Offset(20, 20), 18, outerPaint);

    // Draw solid inner circle
    canvas.drawCircle(const Offset(20, 20), 10, paint);

    // Draw tiny white center
    final whitePaint = Paint()..color = AppColors.white;
    canvas.drawCircle(const Offset(20, 20), 5, whitePaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(40, 40);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  void _startAnimationLoop() {
    _animationTicker = createTicker((_) {
      final target = _targetDriverPosition;
      if (target == null) return;

      final prev = _animatedDriverPosition ?? target;
      if (prev.latitude == target.latitude &&
          prev.longitude == target.longitude) return;

      final newLat = prev.latitude + (target.latitude - prev.latitude) * 0.12;
      final newLng =
          prev.longitude + (target.longitude - prev.longitude) * 0.12;
      _animatedDriverPosition = LatLng(newLat, newLng);

      _driverMarkerNotifier.value = Marker(
        markerId: const MarkerId('driver'),
        position: _animatedDriverPosition!,
        rotation: _driverRotation,
        icon: _carIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 2,
      );
    });
    _animationTicker?.start();
  }

  Future<void> _loadCarIcon() async {
    try {
      final data = await rootBundle.load('assets/images/carr.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 40);
      final frame = await codec.getNextFrame();
      final resizedBytes =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (resizedBytes != null && mounted) {
        _carIcon = BitmapDescriptor.bytes(resizedBytes.buffer.asUint8List());
        // Force update the marker immediately if it already exists
        if (_animatedDriverPosition != null) {
          _updateDriverPosition(_animatedDriverPosition!);
        }
      }
    } catch (e) {
      AppLogger.warning('Failed to load car icon: $e');
    }
  }

  @override
  void dispose() {
    _animationTicker?.dispose();
    _driverMarkerNotifier.dispose();
    _mapController?.dispose();
    _routeCubit.close();
    super.dispose();
  }

  double _bearing(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180;
    final lng1 = from.longitude * math.pi / 180;
    final lat2 = to.latitude * math.pi / 180;
    final lng2 = to.longitude * math.pi / 180;
    final dLng = lng2 - lng1;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  void _updateDriverPosition(LatLng newLoc) {
    // Always compute rotation if moving
    if (_targetDriverPosition != null && _targetDriverPosition != newLoc) {
      final prev = _animatedDriverPosition ?? _targetDriverPosition!;
      if ((prev.latitude - newLoc.latitude).abs() > 0.00001 ||
          (prev.longitude - newLoc.longitude).abs() > 0.00001) {
        _driverRotation = _bearing(prev, newLoc);
      }
    }

    _targetDriverPosition = newLoc;

    // If no animation has started yet (first time), place marker immediately
    // The animation loop will then interpolate from this position
    _animatedDriverPosition ??= newLoc;

    // Always update the marker immediately so it shows even if driver is stationary
    _driverMarkerNotifier.value = Marker(
      markerId: const MarkerId('driver'),
      position: _animatedDriverPosition!,
      rotation: _driverRotation,
      icon: _carIcon ??
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      anchor: const Offset(0.5, 0.5),
      flat: true,
      zIndexInt: 2,
    );
  }

  // ─── Simulator route command printer ────────────────────────────────────
  bool _routeCommandPrinted = false;
  bool _routeCommandPrinting = false;
  DateTime? _lastRouteCommandPrintAttemptAt;

  Future<void> _printSimulatorRouteCommand(TrackingLoaded state) async {
    if (_routeCommandPrinted || _routeCommandPrinting) return;

    final driverPoint = state.driverLocation;
    final pickupPoint = _tripPoint(state.trip, 'pickup_lat', 'pickup_lng');
    final meetingPoint = _tripPoint(state.trip, 'meeting_lat', 'meeting_lng');
    final destinationPoint =
        _tripPoint(state.trip, 'destination_lat', 'destination_lng');
    if (driverPoint == null ||
        pickupPoint == null ||
        destinationPoint == null ||
        state.routePoints.length < 2) {
      return;
    }

    final separateMeetingPoint =
        meetingPoint != null && !_samePoint(meetingPoint, pickupPoint)
            ? meetingPoint
            : null;
    final approachTarget = separateMeetingPoint ?? pickupPoint;
    final now = DateTime.now();
    final lastAttempt = _lastRouteCommandPrintAttemptAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 18)) {
      return;
    }

    _routeCommandPrinting = true;
    _lastRouteCommandPrintAttemptAt = now;

    try {
      final approachPoints = await _loadDriverApproachForCommand(
        driverPoint: driverPoint,
        targetPoint: approachTarget,
      );
      if (!mounted || approachPoints == null) return;

      final fullRoutePoints = approachPoints.length >= 2
          ? _mergeRoutePoints(approachPoints, state.routePoints)
          : state.routePoints;
      if (fullRoutePoints.length < 2) return;

      _routeCommandPrinted = true;
      AppLogger.debug(_simulatorRouteCommand(fullRoutePoints));
    } finally {
      _routeCommandPrinting = false;
    }
  }

  Future<List<LatLng>?> _loadDriverApproachForCommand({
    required LatLng driverPoint,
    required LatLng targetPoint,
  }) async {
    if (_distanceMeters(driverPoint, targetPoint) <= 55) {
      return const [];
    }

    if (_driverApproachRoutePoints.length >= 2 &&
        _distanceMeters(_driverApproachRoutePoints.first, driverPoint) <= 120 &&
        _distanceMeters(_driverApproachRoutePoints.last, targetPoint) <= 120) {
      return _driverApproachRoutePoints;
    }

    final result = await DirectionsService.getRoute(
      originLat: driverPoint.latitude,
      originLng: driverPoint.longitude,
      destLat: targetPoint.latitude,
      destLng: targetPoint.longitude,
      apiKey: EnvConstants.googleMapsApiKey,
    );
    if (result == null || result.points.length < 2) return null;
    return result.points;
  }

  String _simulatorRouteCommand(List<LatLng> routePoints) {
    final deviceId = '4974EF7A-D797-4988-947C-C06ED3D50A7E';
    final buffer = StringBuffer(
      'xcrun simctl location $deviceId start --speed=50 --interval=1',
    );

    for (final point in routePoints) {
      buffer.write(' ${_formatRoutePoint(point)}');
    }
    return buffer.toString();
  }

  List<LatLng> _mergeRoutePoints(List<LatLng> first, List<LatLng> second) {
    final merged = <LatLng>[...first];
    for (final point in second) {
      if (merged.isNotEmpty && _distanceMeters(merged.last, point) <= 20) {
        continue;
      }
      merged.add(point);
    }
    return merged;
  }

  String _formatRoutePoint(LatLng point) {
    return '${point.latitude.toStringAsFixed(5)},'
        '${point.longitude.toStringAsFixed(5)}';
  }

  // ── color tokens removed (using context theme extensions) ─────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: BlocListener<TrackingBloc, TrackingState>(
        listener: (context, state) {
          // ── Transient error (e.g. cancel failed) → show toast, stay on screen ──
          if (state is TrackingError) {
            AppToast.error(ErrorMapper.getErrorMessage(context, state.message));
            return;
          }

          if (state is TrackingLoaded) {
            final tripStatus = state.trip['status'] as String?;

            if (tripStatus != 'completed' && tripStatus != 'cancelled') {
              final loc = state.driverLocation;
              if (loc != null) {
                _updateDriverPosition(LatLng(loc.latitude, loc.longitude));
              }
            }

            unawaited(_printSimulatorRouteCommand(state));

            if (tripStatus == 'completed') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context
                      .go('${AppRoutes.userRating}?tripId=${state.trip['id']}');
                }
              });
            } else if (tripStatus == 'cancelled') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.go(AppRoutes.userHome);
              });
            }
          }
        },
        child: Scaffold(
          backgroundColor: context.bgColor,
          body: Builder(builder: (context) {
            final state = context.watch<TrackingBloc>().state;
            if (state is TrackingLoading || state is TrackingInitial) {
              return _buildSkeleton(context);
            }
            // TrackingError after a loaded state is transient (handled by listener as toast)
            // Only show full error screen on initial load failure
            if (state is TrackingError) return _buildError(context, state.message);
            if (state is TrackingLoaded) return _buildTracking(context, state);
            return _buildSkeleton(context);
          }),
        ),
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Column(children: [
      Container(height: h * 0.55, color: context.cardColor),
      Expanded(
          child: Container(
        color: context.cardColor,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
              height: 28,
              width: 160,
              decoration: BoxDecoration(
                  color: context.elevatedColor,
                  borderRadius: BorderRadius.circular(14))),
          const SizedBox(height: 20),
          Container(
              height: 80,
              decoration: BoxDecoration(
                  color: context.elevatedColor,
                  borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 12),
          Container(
              height: 80,
              decoration: BoxDecoration(
                  color: context.elevatedColor,
                  borderRadius: BorderRadius.circular(16))),
        ]),
      )),
    ]);
  }

  Widget _buildError(BuildContext context, String message) {
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
                border:
                    Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                color: AppColors.error.withValues(alpha: 0.08)),
            child: const Icon(Icons.cloud_off_rounded,
                size: 40, color: AppColors.error)),
        const SizedBox(height: 24),
        Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: context.textSecondary, fontSize: 14, height: 1.6)),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () =>
              context.read<TrackingBloc>().add(LoadTripTracking(widget.tripId)),
          child: Container(
              height: 50,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ]),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.refresh_rounded,
                    color: AppColors.white, size: 17),
                const SizedBox(width: 7),
                Text(l.retry,
                    style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ])),
        ),
      ]),
    )));
  }

  Widget _buildTracking(BuildContext context, TrackingLoaded state) {
    final l = AppLocalizations.of(context)!;
    // Ensure driver marker is visible as soon as we have a location
    if (state.driverLocation != null) {
      final loc = state.driverLocation!;
      final locLatLng = LatLng(loc.latitude, loc.longitude);
      if (_targetDriverPosition == null) {
        // First time — place immediately, avoid setState-during-build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateDriverPosition(locLatLng);
        });
      } else if (_targetDriverPosition != locLatLng) {
        // Location changed — update without addPostFrameCallback (called from listener)
        _targetDriverPosition = locLatLng;
      }
    }

    // Static markers (pickup & destination) — never change during session
    final staticMarkers = <Marker>{};
    final polylines = <Polyline>{};
    final tripStatus = state.trip['status'] as String?;

    final pickupPoint = _tripPoint(state.trip, 'pickup_lat', 'pickup_lng');
    final meetingPoint = _tripPoint(state.trip, 'meeting_lat', 'meeting_lng');
    final destinationPoint =
        _tripPoint(state.trip, 'destination_lat', 'destination_lng');
    final separateMeetingPoint = meetingPoint != null &&
            pickupPoint != null &&
            !_samePoint(meetingPoint, pickupPoint)
        ? meetingPoint
        : null;
    final driverApproachTarget = separateMeetingPoint ?? pickupPoint;
    final showDriverApproach = _shouldShowDriverApproachRoute(
      status: tripStatus,
      driverPoint: state.driverLocation,
      targetPoint: driverApproachTarget,
    );
    _syncDriverApproachRoute(
      status: tripStatus,
      driverPoint: state.driverLocation,
      targetPoint: driverApproachTarget,
    );
    final driverApproachPoints =
        showDriverApproach ? _driverApproachRoutePoints : const <LatLng>[];

    if (separateMeetingPoint != null) {
      staticMarkers.add(Marker(
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
        zIndexInt: 4,
        infoWindow: InfoWindow(title: l.meetingPointLabel),
      ));
    }
    if (pickupPoint != null) {
      staticMarkers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pickupPoint,
        icon: _routeMarkerIcon(
          cacheKey: 'pickup',
          label: l.pickupPoint,
          color: AppColors.success,
          fallback: _pickupIcon,
          icon: Icons.trip_origin_rounded,
        ),
        anchor: const Offset(0.5, 0.78),
        zIndexInt: 3,
        infoWindow: InfoWindow(title: l.pickupPoint),
      ));
    }
    if (destinationPoint != null) {
      staticMarkers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destinationPoint,
        icon: _routeMarkerIcon(
          cacheKey: 'destination',
          label: l.destination,
          color: AppColors.error,
          fallback: _destIcon,
          icon: Icons.flag_rounded,
        ),
        anchor: const Offset(0.5, 0.78),
        zIndexInt: 3,
        infoWindow: InfoWindow(title: l.destination),
      ));
    }
    // ── Waypoint markers are built reactively inside BlocBuilder below ──
    if (driverApproachPoints.length >= 2) {
      polylines.add(Polyline(
        polylineId: const PolylineId('driver_to_meeting'),
        points: driverApproachPoints,
        color: AppColors.success.withValues(alpha: 0.78),
        width: 4,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ));
    }
    if (state.routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route_bg'),
        points: state.routePoints,
        color: AppColors.primary.withValues(alpha: 0.25),
        width: 12,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 2,
      ));
      polylines.add(Polyline(
        polylineId: const PolylineId('route_fg'),
        points: state.routePoints,
        color: AppColors.primary,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 3,
      ));
    }

    final screenH = MediaQuery.of(context).size.height;
    final mapH = screenH * 0.55;

    return Stack(children: [
      // Full-bleed map — reactive to driver location AND route cubit waypoints
      Positioned.fill(
        child: BlocBuilder<TripRouteCubit, TripRouteState>(
          bloc: _routeCubit,
          builder: (context, routeCubitState) {
            // ✅ Build waypoint markers reactively so map refreshes on add/remove
            final waypointMarkers = <Marker>{};
            final activeStopovers =
                routeCubitState.waypoints.where((w) => w.isStopover).toList();
            _scheduleRouteBoundsFit(state, activeStopovers);
            for (int i = 0; i < activeStopovers.length; i++) {
              final wp = activeStopovers[i];
              waypointMarkers.add(Marker(
                markerId: MarkerId('wp_$i'),
                position: LatLng(wp.lat, wp.lng),
                icon: _routeMarkerIcon(
                  cacheKey: 'stopover_$i',
                  label: l.stopoverNumber(i + 1),
                  color: AppColors.warning,
                  fallback: _waypointIcon,
                  icon: Icons.location_on_rounded,
                ),
                anchor: const Offset(0.5, 0.78),
                zIndexInt: 2,
                infoWindow:
                    InfoWindow(title: wp.address ?? l.stopoverNumber(i + 1)),
              ));
            }
            final combinedMarkers = {...staticMarkers, ...waypointMarkers};

            return Stack(fit: StackFit.expand, children: [
              ExcludeSemantics(
                child: ValueListenableBuilder<Marker?>(
                  valueListenable: _driverMarkerNotifier,
                  builder: (context, driverMarker, _) {
                    final allMarkers = Set<Marker>.from(combinedMarkers);
                    if (driverMarker != null) allMarkers.add(driverMarker);
                    return AppGoogleMap(
                      initialCameraPosition: _defaultCamera,
                      onMapCreated: (ctrl) {
                        _mapController = ctrl;
                        _fitBounds(ctrl, state);
                      },
                      onCameraMove: (position) =>
                          _lastCameraPosition = position,
                      mapStyle: AppMapStyle.auto,
                      buildingsEnabled: false,
                      minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 70,
                        bottom: (screenH - mapH) + 20,
                      ),
                      markers: allMarkers,
                      polylines: polylines,
                    );
                  },
                ),
              ),
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
                  ))),
            ]);
          },
        ),
      ),

      // Header
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
              children: [
                _MapBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () {
                    if (context.canPop())
                      context.pop();
                    else
                      context.go(AppRoutes.userHome);
                  },
                ),
                Expanded(
                  child: Center(child: _statusPill(tripStatus, l)),
                ),
                _MapBtn(
                  icon: _is3DMode ? Icons.view_in_ar : Icons.map_outlined,
                  onTap: () => _toggle3DMode(state),
                ),
                const SizedBox(width: 8),
                _MapBtn(
                  icon: Icons.refresh_rounded,
                  onTap: () => context
                      .read<TrackingBloc>()
                      .add(LoadTripTracking(widget.tripId)),
                ),
              ],
            ),
          ),
        ),
      ),

      // My Location button
      Positioned.directional(
        textDirection: Directionality.of(context),
        top: mapH - 70,
        end: 14,
        child: _MapBtn(
          icon: Icons.my_location_rounded,
          onTap: () async {
            if (_mapController != null && state.driverLocation != null) {
              await _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: state.driverLocation!,
                    zoom: _is3DMode ? 17.2 : 16,
                    tilt: _is3DMode ? 48 : 0,
                    bearing: _is3DMode ? _driverRotation : 0,
                  ),
                ),
              );
            }
          },
        ),
      ),

      // Bottom sheet
      Positioned(
        top: mapH - 12,
        left: 0,
        right: 0,
        bottom: 0,
        child: Container(
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: context.divColor,
                  borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
                child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (state.driver != null) ...[
                      _buildDriverCard(context, state.driver!, state),
                      const SizedBox(height: 12),
                    ],
                    BlocBuilder<TripRouteCubit, TripRouteState>(
                      bloc: _routeCubit,
                      builder: (context, routeState) {
                        final stopovers = routeState.waypoints
                            .where((w) => w.isStopover)
                            .toList();
                        return _buildRouteCard(
                          context,
                          state.trip,
                          l,
                          stopovers,
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Trip stats row
                    _buildTripStatsRow(context, state.trip, l),
                    const SizedBox(height: 12),
                    if (tripStatus != 'completed' && tripStatus != 'cancelled')
                      GestureDetector(
                        onTap: () =>
                            _showCancelDialog(context, widget.tripId, l),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.5),
                                width: 1.2),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cancel_outlined,
                                    color: AppColors.error, size: 17),
                                const SizedBox(width: 7),
                                Text(l.cancelTrip,
                                    style: const TextStyle(
                                        color: AppColors.error,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700)),
                              ]),
                        ),
                      ),
                    SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                  ]),
            )),
          ]),
        ),
      ),
    ]);
  }

  void _scheduleRouteBoundsFit(
    TrackingLoaded state,
    List<TripRouteWaypointModel> stopovers,
  ) {
    if (_mapController == null || state.routePoints.isEmpty) return;
    final first = state.routePoints.first;
    final last = state.routePoints.last;
    final stopoversSignature = stopovers
        .map((w) => '${w.lat.toStringAsFixed(5)},${w.lng.toStringAsFixed(5)}')
        .join('|');
    final signature =
        '${state.routePoints.length}:${first.latitude.toStringAsFixed(5)},'
        '${first.longitude.toStringAsFixed(5)}:${last.latitude.toStringAsFixed(5)},'
        '${last.longitude.toStringAsFixed(5)}:$stopoversSignature';
    if (_lastRouteBoundsSignature == signature) return;
    _lastRouteBoundsSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = _mapController;
      if (!mounted || ctrl == null || _is3DMode) return;
      _fitBounds(ctrl, state);
    });
  }

  void _syncDriverApproachRoute({
    required String? status,
    required LatLng? driverPoint,
    required LatLng? targetPoint,
  }) {
    if (!_shouldShowDriverApproachRoute(
      status: status,
      driverPoint: driverPoint,
      targetPoint: targetPoint,
    )) {
      _clearDriverApproachRoute();
      return;
    }

    final hash = _driverApproachRouteHash(driverPoint!, targetPoint!);
    final now = DateTime.now();
    final lastRequestAt = _lastDriverApproachRouteRequestAt;
    final recentlyRequested = lastRequestAt != null &&
        now.difference(lastRequestAt) < const Duration(seconds: 18);

    if (_lastDriverApproachRouteHash == hash &&
        _driverApproachRoutePoints.length >= 2) {
      return;
    }
    if (recentlyRequested) return;
    if (_driverApproachRouteLoading) return;

    _driverApproachRouteLoading = true;
    _lastDriverApproachRouteHash = hash;
    _lastDriverApproachRouteRequestAt = now;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _lastDriverApproachRouteHash != hash) return;

      final result = await DirectionsService.getRoute(
        originLat: driverPoint.latitude,
        originLng: driverPoint.longitude,
        destLat: targetPoint.latitude,
        destLng: targetPoint.longitude,
        apiKey: EnvConstants.googleMapsApiKey,
      );
      if (!mounted || _lastDriverApproachRouteHash != hash) {
        _driverApproachRouteLoading = false;
        return;
      }

      final points = result != null && result.points.length >= 2
          ? result.points
          : const <LatLng>[];
      setState(() {
        _driverApproachRouteLoading = false;
        _driverApproachRoutePoints = points;
      });
    });
  }

  bool _shouldShowDriverApproachRoute({
    required String? status,
    required LatLng? driverPoint,
    required LatLng? targetPoint,
  }) {
    if (driverPoint == null || targetPoint == null) return false;
    final normalizedStatus = status?.trim().toLowerCase();
    if ({
      'arrived',
      'picked_up',
      'in_progress',
      'completed',
      'cancelled',
      'rejected',
    }.contains(normalizedStatus)) {
      return false;
    }

    final targetHash = _driverApproachTargetHash(targetPoint);
    if (_completedDriverApproachTargetHash == targetHash) return false;
    if (_samePoint(driverPoint, targetPoint) ||
        _distanceMeters(driverPoint, targetPoint) <= 55) {
      _completedDriverApproachTargetHash = targetHash;
      return false;
    }
    return true;
  }

  void _clearDriverApproachRoute() {
    if (_driverApproachRoutePoints.isEmpty &&
        _lastDriverApproachRouteHash == null &&
        !_driverApproachRouteLoading) {
      return;
    }

    _lastDriverApproachRouteHash = null;
    _lastDriverApproachRouteRequestAt = null;
    _driverApproachRouteLoading = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _driverApproachRoutePoints.isEmpty) return;
      setState(() => _driverApproachRoutePoints = const []);
    });
  }

  String _driverApproachRouteHash(LatLng driverPoint, LatLng targetPoint) {
    return '${driverPoint.latitude.toStringAsFixed(4)},'
        '${driverPoint.longitude.toStringAsFixed(4)}>'
        '${_driverApproachTargetHash(targetPoint)}';
  }

  String _driverApproachTargetHash(LatLng targetPoint) {
    return '${targetPoint.latitude.toStringAsFixed(4)},'
        '${targetPoint.longitude.toStringAsFixed(4)}';
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const earthRadiusMeters = 6371000.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLng = (b.longitude - a.longitude) * math.pi / 180;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  Future<void> _toggle3DMode(TrackingLoaded state) async {
    final ctrl = _mapController;
    if (ctrl == null) return;

    final enable3D = !_is3DMode;
    setState(() => _is3DMode = enable3D);

    if (!enable3D) {
      final current = await _currentCameraPosition(ctrl);
      await ctrl.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: current.target,
            zoom: current.zoom,
            tilt: 0,
            bearing: 0,
          ),
        ),
      );
      _fitBounds(ctrl, state);
      return;
    }

    final current = await _currentCameraPosition(ctrl);
    await ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: current.target,
          zoom: current.zoom,
          tilt: 48,
          bearing: _driverRotation,
        ),
      ),
    );
  }

  Future<CameraPosition> _currentCameraPosition(
    GoogleMapController ctrl,
  ) async {
    final cached = _lastCameraPosition;
    if (cached != null) return cached;

    try {
      final bounds = await ctrl.getVisibleRegion();
      final zoom = await ctrl.getZoomLevel();
      return CameraPosition(
          target: MapCameraUtils.centerOf(bounds), zoom: zoom);
    } catch (e, st) {
      AppLogger.warning('TrackingScreen: failed to read current map camera: $e');
      AppLogger.debug(st.toString());
      return CameraPosition(target: AppConstants.defaultMapCenter, zoom: 14);
    }
  }

  Widget _statusPill(String? status, AppLocalizations l) {
    final color = switch (status) {
      'completed' => AppColors.success,
      'cancelled' => AppColors.error,
      'in_progress' || 'accepted' => AppColors.primary,
      'searching' => AppColors.warning,
      _ => context.textSecondary,
    };
    final label = switch (status) {
      'completed' => l.completed,
      'cancelled' => l.cancelled,
      'in_progress' => l.inProgress,
      'accepted' => l.tripAccepted,
      'searching' => l.searchingForDriver,
      _ => l.pending,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.cardColor.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 20),
          BoxShadow(
              color: AppColors.black.withValues(alpha: 0.54), blurRadius: 10),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)
                ])),
        const SizedBox(width: 8),
        Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _buildRouteCard(BuildContext context, Map<String, dynamic> trip,
      AppLocalizations l, List<TripRouteWaypointModel> stopovers) {
    final meeting = (trip['meeting_address'] as String?)?.trim() ?? '';
    final pickup = (trip['pickup_address'] as String?)?.trim() ?? '';
    final dest = (trip['destination_address'] as String?)?.trim() ?? '';
    final pickupPoint = _tripPoint(trip, 'pickup_lat', 'pickup_lng');
    final meetingPoint = _tripPoint(trip, 'meeting_lat', 'meeting_lng');
    final hasSeparateMeeting = meetingPoint != null &&
        pickupPoint != null &&
        !_samePoint(meetingPoint, pickupPoint);
    final showMeeting =
        hasSeparateMeeting || (meeting.isNotEmpty && meeting != pickup);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (showMeeting)
          _routeSummaryRow(
            context: context,
            label: l.meetingPointLabel,
            address: meeting.isEmpty ? l.meetingPointLabel : meeting,
            color: AppColors.primary,
            icon: Icons.groups_rounded,
          ),
        _routeSummaryRow(
          context: context,
          label: l.pickupPoint,
          address: pickup.isEmpty ? l.notAvailable : pickup,
          color: AppColors.success,
          icon: Icons.trip_origin_rounded,
        ),
        ...List.generate(stopovers.length, (index) {
          final waypoint = stopovers[index];
          return _routeSummaryRow(
            context: context,
            label: l.stopoverNumber(index + 1),
            address: waypoint.address ?? l.stopoverNumber(index + 1),
            color: AppColors.warning,
            icon: Icons.location_on_rounded,
          );
        }),
        _routeSummaryRow(
          context: context,
          label: l.destination,
          address: dest.isEmpty ? l.notAvailable : dest,
          color: AppColors.error,
          icon: Icons.flag_rounded,
          isLast: true,
        ),
      ]),
    );
  }

  Widget _routeSummaryRow({
    required BuildContext context,
    required String label,
    required String address,
    required Color color,
    required IconData icon,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.32)),
            ),
            child: Icon(icon, color: color, size: 13),
          ),
          if (!isLast)
            Container(
              width: 2,
              height: 14,
              margin: const EdgeInsets.only(top: 4),
              color: context.divColor,
            ),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label.toUpperCase(),
                style: TextStyle(
                    color: color,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0)),
            const SizedBox(height: 3),
            Text(address,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildDriverCard(
      BuildContext context, Map<String, dynamic> driver, TrackingLoaded state) {
    final avatarUrl = driver['avatar_url'] as String?;
    final tripId = state.trip['id'] as String?;
    final name =
        driver['name'] as String? ?? AppLocalizations.of(context)!.theDriver;
    final rating = driver['rating']?.toString() ?? '0.0';
    final plate = driver['vehicle_plate'] as String? ?? '';
    final driverId = driver['id'] as String?;
    final phone = driver['phone'] as String?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Row(children: [
        // Location center button
        _buildActionIcon(Icons.my_location_rounded, AppColors.warning, () {
          if (_mapController != null && state.driverLocation != null) {
            _mapController!.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(target: state.driverLocation!, zoom: 16),
            ));
          }
        }),
        // Phone button
        if (phone != null) ...[
          const SizedBox(width: 8),
          _buildActionIcon(Icons.phone_rounded, AppColors.success, () {}),
        ],
        // Chat button
        const SizedBox(width: 8),
        _buildActionIcon(Icons.chat_bubble_rounded, AppColors.primary, () {
          if (tripId != null && tripId.isNotEmpty && driverId != null) {
            context.push(
                '${AppRoutes.userMessages}?tripId=$tripId&otherUserId=$driverId&otherUserName=${Uri.encodeComponent(name)}');
          } else {
            context.push(AppRoutes.userMessages);
          }
        }),
        const SizedBox(width: 12),
        // Name + meta
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(name,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Icon(Icons.star_rounded, color: AppColors.warning, size: 13),
            const SizedBox(width: 3),
            Text(rating,
                style: const TextStyle(
                    color: AppColors.warning,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ])),
        const SizedBox(width: 12),
        // Avatar
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
              radius: 24,
              backgroundColor: context.elevatedColor,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800))
                  : null,
            ),
          ),
          Positioned(
              bottom: 1,
              right: 1,
              child: Container(
                  width: 11,
                  height: 11,
                  decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.cardColor, width: 2)))),
        ]),
      ]),
    );
  }

  Widget _buildActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.25), width: 1)),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  void _showCancelDialog(BuildContext ctx, String tripId, AppLocalizations l) {
    final bloc = ctx.read<TrackingBloc>();
    showDialog(
      context: ctx,
      builder: (dialogCtx) => Dialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.warning_rounded,
                      color: AppColors.error, size: 20),
                ),
                const SizedBox(width: 14),
                Text(l.cancelTrip,
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 14),
              Text(l.areYouSureCancelTrip,
                  style: TextStyle(
                      color: context.textSecondary, fontSize: 14, height: 1.6)),
              const SizedBox(height: 24),
              Row(children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(l.noLabel,
                      style: TextStyle(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.of(dialogCtx).pop();
                    bloc.add(CancelTrip(tripId));
                  },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.error,
                          AppColors.error.withValues(alpha: 0.75)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.26),
                            blurRadius: 12,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.check_rounded,
                          color: AppColors.white, size: 17),
                      const SizedBox(width: 7),
                      Text(l.yesCancel,
                          style: const TextStyle(
                              color: AppColors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTripStatsRow(
      BuildContext context, Map<String, dynamic> trip, AppLocalizations l) {
    final dist = (trip['distance_km'] as num?)?.toStringAsFixed(1) ?? '0';
    final price = (trip['price'] as num?)?.toDouble() ?? 0;
    final couponDiscount = (trip['coupon_discount'] as num?)?.toDouble() ?? 0;
    final finalPrice = (trip['final_price'] as num?)?.toDouble() ?? price;
    final hasCoupon = couponDiscount > 0;
    final vType = trip['service_tier_name_snapshot'] as String? ?? trip['vehicle_type'] as String? ?? 'car';
    final pay = trip['payment_method'] as String? ?? 'cash';
    final isPaid = trip['is_paid'] as bool? ?? false;

    final vName = switch (vType) {
      'sedan' => l.sedan,
      'suv' => l.suv,
      'van' => l.van,
      'minibus' => l.minibus,
      'motorcycle' => l.motorcycle,
      _ => l.car,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Price card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.divColor, width: 1),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.fareDetails.toUpperCase(),
                        style: TextStyle(
                            color: context.textDisabled,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 8),

                    // ── Price display (coupon-aware) ──
                    if (hasCoupon) ...[
                      // Original price with strikethrough
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          PriceFormatter.displayCompactWithCurrency(context, price),
                          style: TextStyle(
                            color: context.textDisabled,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: context.textDisabled,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Final price (large)
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
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                    height: 1)),
                            const SizedBox(width: 4),
                            Text(l.currencySar,
                                style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Coupon discount badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppColors.purple.withValues(alpha: 0.25)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.local_offer_rounded,
                              color: AppColors.purple, size: 11),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '-${PriceFormatter.displayWithCurrency(context, couponDiscount)}',
                              style: const TextStyle(
                                  color: AppColors.purple,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                    ] else ...[
                      // Normal price (no coupon)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(PriceFormatter.display(context, price),
                                style: TextStyle(
                                    color: context.textPrimary,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                    height: 1)),
                            const SizedBox(width: 4),
                            Text(l.currencySar,
                                style: TextStyle(
                                    color: context.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],

                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
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
                                color: isPaid
                                    ? AppColors.success
                                    : AppColors.warning,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(isPaid ? l.paid : l.unpaid,
                            style: TextStyle(
                                color: isPaid
                                    ? AppColors.success
                                    : AppColors.warning,
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ]),
            ),
          ),
          const SizedBox(width: 12),
          // Stats card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: context.divColor, width: 1),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.tripDetails.toUpperCase(),
                        style: TextStyle(
                            color: context.textDisabled,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    _buildStatItem(Icons.straighten_rounded, AppColors.primary,
                        '$dist ${l.km}'),
                    const SizedBox(height: 8),
                    _buildStatItem(
                        Icons.directions_car_rounded, AppColors.purple, vName),
                    const SizedBox(height: 8),
                    _buildStatItem(
                      pay == 'cash'
                          ? Icons.payments_rounded
                          : Icons.credit_card_rounded,
                      AppColors.warning,
                      pay == 'cash' ? l.cash : l.bankCard,
                    ),
                  ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, Color color, String label) {
    return Row(children: [
      Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, color: color, size: 13),
      ),
      const SizedBox(width: 8),
      Flexible(
          child: Text(label,
              style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600))),
    ]);
  }

  LatLng? _tripPoint(Map<String, dynamic> trip, String latKey, String lngKey) {
    final lat = (trip[latKey] as num?)?.toDouble();
    final lng = (trip[lngKey] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    if (lat == 0.0 && lng == 0.0) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    return LatLng(lat, lng);
  }

  bool _samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00005 &&
        (a.longitude - b.longitude).abs() < 0.00005;
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

  void _fitBounds(GoogleMapController ctrl, TrackingLoaded state) {
    final points = <LatLng>[];
    if (state.trip['pickup_lat'] != null &&
        state.trip['pickup_lng'] != null &&
        state.trip['pickup_lat'] != 0.0 &&
        state.trip['pickup_lng'] != 0.0) {
      points.add(LatLng(
        (state.trip['pickup_lat'] as num).toDouble(),
        (state.trip['pickup_lng'] as num).toDouble(),
      ));
    }
    if (state.trip['meeting_lat'] != null &&
        state.trip['meeting_lng'] != null &&
        state.trip['meeting_lat'] != 0.0 &&
        state.trip['meeting_lng'] != 0.0) {
      points.add(LatLng(
        (state.trip['meeting_lat'] as num).toDouble(),
        (state.trip['meeting_lng'] as num).toDouble(),
      ));
    }
    if (state.trip['destination_lat'] != null &&
        state.trip['destination_lng'] != null &&
        state.trip['destination_lat'] != 0.0 &&
        state.trip['destination_lng'] != 0.0) {
      points.add(LatLng(
        (state.trip['destination_lat'] as num).toDouble(),
        (state.trip['destination_lng'] as num).toDouble(),
      ));
    }
    if (state.routePoints.isNotEmpty)
      points.addAll(state.routePoints
          .where((p) => p.latitude != 0.0 && p.longitude != 0.0));
    // Include waypoint stopovers in bounds
    final wpState = _routeCubit.state;
    for (final wp in wpState.waypoints.where((w) => w.isStopover)) {
      points.add(LatLng(wp.lat, wp.lng));
    }

    if (points.isEmpty) return;

    MapCameraUtils.fitCameraToPoints(
      ctrl,
      points,
      padding: 42,
      minimumLatSpan: 0.0007,
      minimumLngSpan: 0.0007,
    );
  }
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: context.cardColor.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: context.divColor, width: 1),
            boxShadow: [
              BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.15),
                  blurRadius: 10)
            ],
          ),
          child: Icon(icon, color: context.textPrimary, size: 18),
        ),
      );
}
