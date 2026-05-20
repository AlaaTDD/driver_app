import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bloc/trip_details_bloc.dart';
import 'bloc/trip_details_event.dart';
import 'bloc/trip_details_state.dart';
import '../../../trips/presentation/bloc/trip_route_cubit.dart';
import '../../../trips/presentation/widgets/waypoints_timeline.dart';
import '../../../../core/models/trip_route_waypoint_model.dart';
import 'package:geocoding/geocoding.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/map/app_map.dart';
import '../../../../services/directions_service.dart';
import '../../../../services/location_service.dart';
import '../../../../core/constants/env_constants.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;
import 'package:snapix/core/theme/app_colors.dart';
import '../../../../core/utils/map_camera_utils.dart';
import 'package:snapix/core/theme/theme_extensions.dart';
import 'package:snapix/core/utils/app_toast.dart';

// _C palette removed

// ─── Screen ───────────────────────────────────────────────────────────────────
class DriverTripDetailsScreen extends StatefulWidget {
  final String tripId;
  const DriverTripDetailsScreen({super.key, required this.tripId});

  @override
  State<DriverTripDetailsScreen> createState() =>
      _DriverTripDetailsScreenState();
}

class _DriverTripDetailsScreenState extends State<DriverTripDetailsScreen>
    with TickerProviderStateMixin {
  // map
  final Completer<GoogleMapController> _mapController = Completer();
  List<LatLng> _routePoints = [];
  bool _routeFetchRequested = false;
  String _lastStopoversHash = '';
  CameraPosition? _lastCameraPosition;
  List<LatLng> _driverApproachRoutePoints = const [];
  String? _lastDriverApproachRouteHash;
  DateTime? _lastDriverApproachRouteRequestAt;
  bool _driverApproachRouteLoading = false;
  String? _completedDriverApproachTargetHash;
  final Map<String, BitmapDescriptor> _routeMarkerIcons = {};
  final Set<String> _pendingRouteMarkerIcons = {};
  String? _routeMarkerLocaleCode;
  bool _is3DMode = false;
  Map<String, dynamic>? _trip;

  // driver location
  StreamSubscription<Position>? _locationSub;
  LatLng? _driverLocation;
  BitmapDescriptor? _carIcon;
  double _driverHeading = 0.0;
  bool _cameraFollowing = false;

  final ValueNotifier<Marker?> _driverMarkerNotifier =
      ValueNotifier<Marker?>(null);
  LatLng? _animatedDriverPosition;
  LatLng? _targetDriverPosition;
  double _driverRotation = 0.0;
  Ticker? _animationTicker;

  // animations
  late AnimationController _sheetCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _shimCtrl;
  late Animation<double> _sheetAnim;
  late Animation<double> _fadeAnim;
  late Animation<double> _pulseAnim;

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

    _loadCarIcon();
    _loadCircleIcons();
    context.read<TripDetailsBloc>().add(LoadTripDetails(widget.tripId));
    _startLocationTracking();
    _startAnimationLoop();
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
    _pickupIcon = await _createCircleMarker(AppColors.success);
    _destIcon = await _createCircleMarker(AppColors.error);
    _waypointIcon = await _createCircleMarker(AppColors.warning);
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createCircleMarker(Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;

    final outerPaint = Paint()..color = color.withOpacity(0.2);
    canvas.drawCircle(const Offset(20, 20), 18, outerPaint);
    canvas.drawCircle(const Offset(20, 20), 10, paint);

    final whitePaint = Paint()..color = AppColors.white;
    canvas.drawCircle(const Offset(20, 20), 5, whitePaint);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(40, 40);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _loadCarIcon() async {
    try {
      final data = await rootBundle.load('assets/images/carr.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 40);
      final frame = await codec.getNextFrame();
      final resized =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (resized != null && mounted) {
        setState(() =>
            _carIcon = BitmapDescriptor.bytes(resized.buffer.asUint8List()));
        if (_animatedDriverPosition != null) {
          _updateDriverPosition(_animatedDriverPosition!);
        }
      }
    } catch (e) {
      debugPrint('⚠️ car icon: $e');
    }
  }

  void _startLocationTracking() {
    _locationSub =
        LocationService.instance.getLocationStream().listen((pos) async {
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _driverLocation = loc;
        _driverHeading = pos.heading;
      });
      _updateDriverPosition(loc);
      if (_cameraFollowing && _mapController.isCompleted) {
        final ctrl = await _mapController.future;
        if (mounted) {
          try {
            ctrl.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(
                target: _driverLocation!,
                zoom: _is3DMode ? 17.2 : 16,
                tilt: _is3DMode ? 48 : 0,
                bearing: _driverHeading,
              ),
            ));
          } catch (e) {
            debugPrint('animateCamera error: $e');
          }
        }
      }
    });
  }

  void _updateDriverPosition(LatLng newLoc) {
    if (!mounted) return;
    if (_targetDriverPosition != null && _targetDriverPosition != newLoc) {
      final prev = _animatedDriverPosition ?? _targetDriverPosition!;
      if ((prev.latitude - newLoc.latitude).abs() > 0.00001 ||
          (prev.longitude - newLoc.longitude).abs() > 0.00001) {
        _driverRotation = _bearing(prev, newLoc);
      }
    }
    _targetDriverPosition = newLoc;
    _animatedDriverPosition ??= newLoc;

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
  }

  double _bearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * math.pi / 180.0;
    double lng1 = start.longitude * math.pi / 180.0;
    double lat2 = end.latitude * math.pi / 180.0;
    double lng2 = end.longitude * math.pi / 180.0;
    double dLng = lng2 - lng1;
    double y = math.sin(dLng) * math.cos(lat2);
    double x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
    double brng = math.atan2(y, x);
    return (brng * 180.0 / math.pi + 360.0) % 360.0;
  }

  void _startAnimationLoop() {
    _animationTicker ??= createTicker((_) {
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
    if (_mapController.isCompleted) {
      final ctrl = await _mapController.future;
      if (!mounted || _cameraFollowing || _is3DMode) return;
      _fitMapBounds(ctrl, const <Marker>{});
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    _animationTicker?.dispose();
    _driverMarkerNotifier.dispose();
    _sheetCtrl.dispose();
    _pulseCtrl.dispose();
    _shimCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════
  bool _animationTriggered = false;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: Theme.of(context).brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.bgColor,
        body: BlocConsumer<TripDetailsBloc, TripDetailsState>(
          listener: (ctx, state) {
            if (state is TripDetailsLoaded) {
              final status = state.trip['status'] as String?;
              if (status == 'completed') {
                _toast(ctx, AppLocalizations.of(ctx)!.tripCompleted, ok: true);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (ctx.mounted) {
                    ctx.go('${AppRoutes.driverRating}?tripId=${widget.tripId}');
                  }
                });
                return;
              }
              if (!_animationTriggered) {
                _animationTriggered = true;
                _sheetCtrl.forward(from: 0);
              }
            } else if (state is TripDetailsError) {
              _toast(ctx, state.message, ok: false);
            } else if (state is TripCancelled) {
              _toast(ctx, AppLocalizations.of(ctx)!.cancelTrip, ok: true);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (ctx.mounted) {
                  ctx.go(AppRoutes.driverHome);
                }
              });
            }
          },
          builder: (ctx, state) {
            if (state is TripDetailsLoaded) {
              _trip = state.trip;
              return _body(state.trip);
            }
            if (state is TripDetailsError) {
              if (_trip != null) return _body(_trip!);
              return _errorView(state.message);
            }
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
        _Btn(
          label: l.retry,
          icon: Icons.refresh_rounded,
          color: AppColors.primary,
          onTap: () => context
              .read<TripDetailsBloc>()
              .add(LoadTripDetails(widget.tripId)),
        ),
      ]),
    )));
  }

  // ══════════════════════════════════════════════════════════
  // MAIN BODY
  // ══════════════════════════════════════════════════════════
  Widget _body(Map<String, dynamic> trip) {
    final status = trip['status'] as String?;
    final screenH = MediaQuery.of(context).size.height;
    final mapH = screenH * 0.44;
    final pLat = (trip['pickup_lat'] as num?)?.toDouble();
    final pLng = (trip['pickup_lng'] as num?)?.toDouble();
    final dLat = (trip['destination_lat'] as num?)?.toDouble();
    final dLng = (trip['destination_lng'] as num?)?.toDouble();
    final hasAction = _hasAction(status);

    return Stack(children: [
      // ── [1] Map (rebuilds when waypoints change)
      Positioned.fill(
        child: BlocBuilder<TripRouteCubit, TripRouteState>(
          builder: (context, routeState) {
            final stopovers =
                routeState.waypoints.where((w) => w.isStopover).toList();
            return _buildMap(
                trip, pLat, pLng, dLat, dLng, screenH - mapH, stopovers);
          },
        ),
      ),

      // ── [2] Header (Back button & Status pill)
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
                _MapCircleBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.pop()),
                Expanded(
                  child: Center(child: _statusPill(status)),
                ),
                _MapCircleBtn(
                  icon: _is3DMode ? Icons.view_in_ar : Icons.map_outlined,
                  onTap: _toggle3DMode,
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
        child: _MapCircleBtn(
          icon: _cameraFollowing
              ? Icons.my_location_rounded
              : Icons.location_searching_rounded,
          onTap: () async {
            setState(() => _cameraFollowing = true);
            if (_driverLocation != null && _mapController.isCompleted) {
              final ctrl = await _mapController.future;
              if (mounted) {
                try {
                  ctrl.animateCamera(CameraUpdate.newCameraPosition(
                    CameraPosition(
                        target: _driverLocation!,
                        zoom: _is3DMode ? 17.2 : 16,
                        tilt: _is3DMode ? 48 : 0,
                        bearing: _is3DMode ? _driverHeading : 0),
                  ));
                } catch (e) {
                  debugPrint('animateCamera error: $e');
                }
              }
            }
          },
        ),
      ),

      // ── [4] Sliding bottom sheet
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
                Expanded(
                    child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // User card
                        if (trip['user'] != null) ...[
                          _UserStrip(
                              user: trip['user'] as Map, tripId: widget.tripId),
                          const SizedBox(height: 13),
                        ],

                        // Route ticket / Waypoints Timeline (driver = read-only, no add/remove)
                        BlocBuilder<TripRouteCubit, TripRouteState>(
                          builder: (context, routeState) {
                            final isActive = trip['status'] == 'in_progress' ||
                                trip['status'] == 'accepted';
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (routeState.waypoints.isNotEmpty)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: context.cardColor,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: context.divColor, width: 1),
                                    ),
                                    padding: const EdgeInsets.all(16),
                                    child: WaypointsTimeline(
                                      waypoints: routeState.waypoints,
                                      isEditable:
                                          false, // Driver cannot add/remove
                                      onMarkArrived: isActive
                                          ? (id) => context
                                              .read<TripRouteCubit>()
                                              .markArrived(id)
                                          : null,
                                      onMarkDeparted: isActive
                                          ? (id) => context
                                              .read<TripRouteCubit>()
                                              .markDeparted(id)
                                          : null,
                                      isDriver: true,
                                    ),
                                  )
                                else
                                  _RouteTicket(trip: trip),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 13),

                        // Price + Stats
                        IntrinsicHeight(
                            child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: _PriceBox(trip: trip)),
                            const SizedBox(width: 12),
                            Expanded(child: _StatsBox(trip: trip)),
                          ],
                        )),
                        const SizedBox(height: 13),

                        // Timeline
                        _HTimeline(trip: trip),

                        SizedBox(
                            height: !hasAction
                                ? 20
                                : (status == 'accepted' ||
                                        status == 'in_progress')
                                    ? 150
                                    : 90),
                      ]),
                )),
              ]),
            ),
          ),
        ),
      ),

      // ── [5] Sticky action bar
      if (hasAction)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: _ActionBar(
              status: status,
              onAccept: () => context
                  .read<TripDetailsBloc>()
                  .add(AcceptTrip(widget.tripId)),
              onReject: () => _rejectDialog(),
              onStart: () =>
                  context.read<TripDetailsBloc>().add(StartTrip(widget.tripId)),
              onComplete: () => _completeDialog(),
              onCancel: () => _cancelDialog(),
            ),
          ),
        ),
    ]);
  }

  bool _hasAction(String? s) =>
      {'searching', 'pending', 'accepted', 'in_progress'}.contains(s);

  // ── Map ────────────────────────────────────────────────────────────────────
  Widget _buildMap(Map<String, dynamic> trip, double? pLat, double? pLng,
      double? dLat, double? dLng, double bottomPadding,
      [List<TripRouteWaypointModel> stopovers = const []]) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final l = AppLocalizations.of(context)!;
    final tripStatus = trip['status'] as String?;
    final pickupPoint = _tripPoint(trip, 'pickup_lat', 'pickup_lng');
    final meetingPoint = _tripPoint(trip, 'meeting_lat', 'meeting_lng');
    final destinationPoint =
        _tripPoint(trip, 'destination_lat', 'destination_lng');
    final separateMeetingPoint = meetingPoint != null &&
            pickupPoint != null &&
            !_samePoint(meetingPoint, pickupPoint)
        ? meetingPoint
        : null;
    final routeStart =
        separateMeetingPoint ?? (pickupPoint ?? AppConstants.defaultMapCenter);
    final routeWaypoints = <LatLng>[
      if (separateMeetingPoint != null && pickupPoint != null) pickupPoint,
      ...stopovers.map((w) => LatLng(w.lat, w.lng)),
    ];
    final driverApproachTarget = separateMeetingPoint ?? pickupPoint;
    final showDriverApproach = _shouldShowDriverApproachRoute(
      status: tripStatus,
      driverPoint: _driverLocation,
      targetPoint: driverApproachTarget,
    );
    _syncDriverApproachRoute(
      status: tripStatus,
      driverPoint: _driverLocation,
      targetPoint: driverApproachTarget,
    );
    final driverApproachPoints =
        showDriverApproach ? _driverApproachRoutePoints : const <LatLng>[];

    if (separateMeetingPoint != null) {
      markers.add(Marker(
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
      markers.add(Marker(
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
        infoWindow: InfoWindow(
            title: trip['pickup_address'] as String? ?? l.pickupPoint),
      ));
    }
    if (destinationPoint != null) {
      markers.add(Marker(
        markerId: const MarkerId('dest'),
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
        infoWindow: InfoWindow(
            title: trip['destination_address'] as String? ?? l.destination),
      ));
    }
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
        zIndexInt: 2,
        infoWindow: InfoWindow(title: wp.address ?? label),
      ));
    }

    // fetch route once or when route points change.
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
    if (_routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route_bg'),
        points: _routePoints,
        color: AppColors.primary.withValues(alpha: 0.25),
        width: 12,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 2,
      ));
      polylines.add(Polyline(
        polylineId: const PolylineId('route_fg'),
        points: _routePoints,
        color: AppColors.primary,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 3,
      ));
    }

    final initTarget = pLat != null && pLng != null
        ? LatLng(pLat, pLng)
        : AppConstants.defaultMapCenter;

    return Stack(fit: StackFit.expand, children: [
      ValueListenableBuilder<Marker?>(
        valueListenable: _driverMarkerNotifier,
        builder: (context, driverMarker, _) {
          final allMarkers = Set<Marker>.from(markers);
          if (driverMarker != null) allMarkers.add(driverMarker);
          return ExcludeSemantics(
              child: AppGoogleMap(
            initialCameraPosition: CameraPosition(target: initTarget, zoom: 15),
            mapStyle: AppMapStyle.auto,
            buildingsEnabled: false,
            minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 70,
              bottom: bottomPadding + 20,
            ),
            onMapCreated: (ctrl) {
              if (!_mapController.isCompleted) _mapController.complete(ctrl);
              if (_driverLocation != null && _cameraFollowing) {
                ctrl.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(
                      target: _driverLocation!,
                      zoom: _is3DMode ? 17.2 : 16,
                      tilt: _is3DMode ? 48 : 0,
                      bearing: _is3DMode ? _driverHeading : 0),
                ));
              } else {
                _fitMapBounds(ctrl, markers);
              }
            },
            onCameraMove: (position) => _lastCameraPosition = position,
            onCameraMoveStarted: () => setState(() => _cameraFollowing = false),
            markers: allMarkers,
            polylines: polylines,
          ));
        },
      ),
      // bottom fade
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

  void _fitMapBounds(GoogleMapController ctrl, Set<Marker> markers) {
    final pts = markers
        .map((m) => m.position)
        .where((p) => p.latitude != 0.0 && p.longitude != 0.0)
        .toList();
    pts.addAll(_routePoints.where(
      (p) => p.latitude != 0.0 && p.longitude != 0.0,
    ));
    if (pts.isEmpty) return;
    MapCameraUtils.fitCameraToPoints(
      ctrl,
      pts,
      padding: 42,
      minimumLatSpan: 0.0007,
      minimumLngSpan: 0.0007,
    );
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

  Future<void> _toggle3DMode() async {
    if (!_mapController.isCompleted) return;
    final ctrl = await _mapController.future;

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
      _fitMapBounds(ctrl, const <Marker>{});
      return;
    }

    final current = await _currentCameraPosition(ctrl);
    await ctrl.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: current.target,
          zoom: current.zoom,
          tilt: 48,
          bearing: _driverHeading,
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
    } catch (_) {
      return CameraPosition(target: AppConstants.defaultMapCenter, zoom: 14);
    }
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
          decoration: BoxDecoration(
            color: context.cardColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
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
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _cancelDialog() {
    final l = AppLocalizations.of(context)!;
    showDialog(
        context: context,
        builder: (_) => _NightDialog(
              icon: Icons.cancel_outlined,
              iconColor: AppColors.error,
              title: l.cancelTrip,
              body: l.areYouSureCancelTrip,
              confirmLabel: l.yesCancel,
              confirmColor: AppColors.error,
              cancelLabel: l.cancel,
              onConfirm: () {
                final bloc = context.read<TripDetailsBloc>();
                context.pop();
                Future.delayed(const Duration(milliseconds: 150), () {
                  bloc.add(CancelTrip(widget.tripId));
                });
              },
            ));
  }

  void _rejectDialog() {
    final l = AppLocalizations.of(context)!;
    showDialog(
        context: context,
        builder: (_) => _NightDialog(
              icon: Icons.cancel_outlined,
              iconColor: AppColors.error,
              title: l.reject,
              body: l.areYouSureRejectTrip,
              confirmLabel: l.reject,
              confirmColor: AppColors.error,
              cancelLabel: l.cancel,
              onConfirm: () {
                final bloc = context.read<TripDetailsBloc>();
                context.pop();
                Future.delayed(const Duration(milliseconds: 150), () {
                  bloc.add(RejectTrip(widget.tripId));
                });
              },
            ));
  }

  void _completeDialog() {
    final l = AppLocalizations.of(context)!;
    showDialog(
        context: context,
        builder: (_) => _NightDialog(
              icon: Icons.check_circle_outline_rounded,
              iconColor: AppColors.success,
              title: l.completeTrip,
              body: l.areYouSureCompleteTrip,
              confirmLabel: l.completeTrip,
              confirmColor: AppColors.success,
              cancelLabel: l.cancel,
              onConfirm: () {
                final bloc = context.read<TripDetailsBloc>();
                context.pop();
                Future.delayed(const Duration(milliseconds: 150), () {
                  bloc.add(CompleteTrip(widget.tripId));
                });
              },
            ));
  }

  // Driver does NOT have add/remove stopover capability — only the user can manage waypoints.

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _statusColor(String? s) => switch (s) {
        'completed' => AppColors.success,
        'cancelled' => AppColors.error,
        'in_progress' || 'accepted' => AppColors.primary,
        'searching' || 'pending' => AppColors.warning,
        _ => context.textSecondary,
      };

  IconData _statusIcon(String? s) => switch (s) {
        'completed' => Icons.check_circle_rounded,
        'cancelled' => Icons.cancel_rounded,
        'in_progress' => Icons.local_taxi_rounded,
        'accepted' => Icons.thumb_up_rounded,
        'searching' || 'pending' => Icons.radar_rounded,
        _ => Icons.help_outline_rounded,
      };

  String _statusLabel(String? s) {
    final l = AppLocalizations.of(context)!;
    return switch (s) {
      'completed' => l.completed,
      'cancelled' => l.cancelled,
      'in_progress' => l.inProgress,
      'accepted' => l.tripAccepted,
      'searching' || 'pending' => l.searchingForDriver,
      _ => l.pending,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUB-WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

// ── Floating map button ───────────────────────────────────────────────────────
class _MapCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MapCircleBtn({required this.icon, required this.onTap});

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
                  color: AppColors.black.withValues(alpha: 0.38),
                  blurRadius: 10)
            ],
          ),
          child: Icon(icon, color: context.textPrimary, size: 18),
        ),
      );
}

// ── User strip (passenger info) ───────────────────────────────────────────────
class _UserStrip extends StatelessWidget {
  final Map user;
  final String tripId;
  const _UserStrip({required this.user, required this.tripId});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final name = user['name'] as String? ?? l.userDefault;
    final avatarUrl = user['avatar_url'] as String?;
    final rating = user['rating']?.toString() ?? '0.0';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Row(children: [
        // Avatar
        Stack(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.purple, AppColors.purpleDark],
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
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: TextStyle(
                          color: AppColors.purple,
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
                  ))),
        ]),
        const SizedBox(width: 12),

        // Name + rating
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
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
              ),
              child: Text(l.passenger,
                  style: TextStyle(
                      color: AppColors.purple,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0)),
            ),
          ]),
        ])),

        // Chat icon
        _CircleAction(
          icon: Icons.chat_bubble_rounded,
          color: AppColors.primary,
          onTap: () {
            final uId = user['id'] as String?;
            if (uId != null) {
              context.push(
                  '${AppRoutes.driverMessages}?tripId=$tripId&otherUserId=$uId&otherUserName=${Uri.encodeComponent(name)}');
            } else {
              context.push('${AppRoutes.driverMessages}?tripId=$tripId');
            }
          },
        ),
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

// ── Route Ticket ──────────────────────────────────────────────────────────────
class _RouteTicket extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _RouteTicket({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final pickup = trip['meeting_address'] ?? trip['pickup_address'] ?? '';
    final dest = trip['destination_address'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Stack(children: [
        Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Center(
                child: Container(
                    width: 5,
                    height: 28,
                    decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8)))))),
        Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Center(
                child: Container(
                    width: 5,
                    height: 28,
                    decoration: BoxDecoration(
                        color: context.cardColor,
                        borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(8),
                            bottomLeft: Radius.circular(8)))))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(children: [
                    Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.success,
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.5),
                                blurRadius: 6)
                          ],
                        )),
                    const SizedBox(width: 7),
                    Text(l.meetingPointLabel.toUpperCase(),
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                  ]),
                  const SizedBox(height: 8),
                  Text(pickup,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35)),
                ])),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ...List.generate(
                    5,
                    (i) => Container(
                        width: 3,
                        height: 3,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: i.isEven
                              ? context.divColor
                              : AppColors.transparent,
                          shape: BoxShape.circle,
                        ))),
                const SizedBox(height: 4),
                Icon(Icons.east_rounded, color: context.textDisabled, size: 14),
              ]),
            ),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(l.destination.toUpperCase(),
                        style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                    const SizedBox(width: 7),
                    Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          boxShadow: [
                            BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.25),
                                blurRadius: 6)
                          ],
                        )),
                  ]),
                  const SizedBox(height: 8),
                  Text(dest,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35)),
                ])),
          ]),
        ),
      ]),
    );
  }
}

// ── Price Box (coupon-aware) ───────────────────────────────────────────────────
class _PriceBox extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _PriceBox({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final price = (trip['price'] as num?)?.toDouble() ?? 0;
    final couponDiscount = (trip['coupon_discount'] as num?)?.toDouble() ?? 0;
    final finalPrice = (trip['final_price'] as num?)?.toDouble() ?? price;
    final driverEarnings = (trip['driver_earnings'] as num?)?.toDouble();
    final platformCommission =
        (trip['platform_commission'] as num?)?.toDouble();
    final isPaid = trip['is_paid'] as bool? ?? false;
    final hasCoupon = couponDiscount > 0;

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

        // ── Original fare (large) ─────────────────
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price.toStringAsFixed(0),
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

        // ── Coupon discount badge ─────────────────
        if (hasCoupon) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.local_offer_rounded,
                  color: AppColors.purple, size: 12),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  '${l.discount}: -${l.priceWithCurrency(couponDiscount.toStringAsFixed(0), l.currencySar)}',
                  style: TextStyle(
                      color: AppColors.purple,
                      fontSize: 10,
                      fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 4),
          // Platform subsidy credit
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.success.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              Icon(Icons.verified_rounded,
                  color: AppColors.success.withValues(alpha: 0.8), size: 11),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  l.platformCoveredCoupon,
                  style: TextStyle(
                      color: AppColors.success.withValues(alpha: 0.8),
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                  '+${l.priceWithCurrency(couponDiscount.toStringAsFixed(0), l.currencySar)}',
                  style: TextStyle(
                      color: AppColors.success.withValues(alpha: 0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w800),
                  textDirection: TextDirection.ltr),
            ]),
          ),
        ],

        // ── Driver earnings row ───────────────────
        if (driverEarnings != null && driverEarnings > 0) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.account_balance_wallet_rounded,
                  color: AppColors.primary, size: 13),
              const SizedBox(width: 6),
              Expanded(
                child: Text(l.yourEarnings,
                    style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ),
              Text(
                  l.priceWithCurrency(
                      driverEarnings.toStringAsFixed(2), l.currencySar),
                  style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800),
                  textDirection: TextDirection.ltr),
            ]),
          ),
        ],

        // ── Platform commission row ───────────────
        if (platformCommission != null && platformCommission > 0) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(children: [
              Icon(Icons.receipt_long_rounded,
                  color: context.textDisabled, size: 10),
              const SizedBox(width: 5),
              Expanded(
                child: Text(l.commission,
                    style: TextStyle(
                        color: context.textDisabled,
                        fontSize: 9,
                        fontWeight: FontWeight.w500)),
              ),
              Text(
                  l.priceWithCurrency(
                      platformCommission.toStringAsFixed(2), l.currencySar),
                  style: TextStyle(
                      color: context.textDisabled,
                      fontSize: 9,
                      fontWeight: FontWeight.w600),
                  textDirection: TextDirection.ltr),
            ]),
          ),
        ],

        const Spacer(),

        // ── Paid / Unpaid badge ───────────────────
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
      ]),
    );
  }
}

// ── Stats Box ─────────────────────────────────────────────────────────────────
class _StatsBox extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _StatsBox({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final dist = (trip['distance_km'] as num?)?.toStringAsFixed(1) ?? '0';
    final vType = trip['vehicle_type'] as String? ?? 'car';
    final pay = trip['payment_method'] as String? ?? 'cash';

    final vName = switch (vType) {
      'sedan' => l.sedan,
      'suv' => l.suv,
      'van' => l.van,
      'minibus' => l.minibus,
      'motorcycle' => l.motorcycle,
      _ => l.car,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.tripDetails.toUpperCase(),
            style: TextStyle(
                color: context.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8)),
        const SizedBox(height: 14),
        _StatRow(
            icon: Icons.straighten_rounded,
            color: AppColors.primary,
            label: l.distanceWithKm(dist)),
        const SizedBox(height: 10),
        _StatRow(
            icon: Icons.directions_car_rounded,
            color: AppColors.purple,
            label: vName),
        const SizedBox(height: 10),
        _StatRow(
          icon: pay == 'cash'
              ? Icons.payments_rounded
              : Icons.credit_card_rounded,
          color: AppColors.warning,
          label: pay == 'cash' ? l.cash : l.bankCard,
        ),
      ]),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _StatRow(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14)),
        const SizedBox(width: 10),
        Flexible(
            child: Text(label,
                style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600))),
      ]);
}

// ── Horizontal Timeline ───────────────────────────────────────────────────────
class _HTimeline extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _HTimeline({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final steps = [
      (l.tripRequest, trip['created_at'], true),
      (l.acceptTrip, trip['accepted_at'], trip['accepted_at'] != null),
      (l.startTrip, trip['started_at'], trip['started_at'] != null),
      (l.completeTrip, trip['completed_at'], trip['completed_at'] != null),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.timeline.toUpperCase(),
            style: TextStyle(
                color: context.textDisabled,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8)),
        const SizedBox(height: 18),
        Row(
          children: steps.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            final done = s.$3 as bool;
            final isLast = i == steps.length - 1;
            String t = '';
            final raw = s.$2;
            if (raw != null) {
              try {
                final dt = DateTime.parse(raw.toString()).toLocal();
                t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              } catch (e, st) {
                debugPrint(
                    '⚠️ DriverTripDetailsScreen: invalid timeline timestamp "$raw": $e\n$st');
              }
            }

            return Expanded(
                child: Row(children: [
              Expanded(
                  child: Column(children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? AppColors.success : context.elevatedColor,
                    border: done
                        ? null
                        : Border.all(color: context.divColor, width: 1.5),
                    boxShadow: done
                        ? [
                            BoxShadow(
                                color: AppColors.success.withValues(alpha: 0.4),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.white, size: 11)
                      : null,
                ),
                const SizedBox(height: 7),
                Text(s.$1,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: done ? context.textPrimary : context.textDisabled,
                      fontSize: 9.5,
                      fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                      height: 1.3,
                    )),
                if (t.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(t,
                      style: TextStyle(
                          color: AppColors.success,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700)),
                ],
              ])),
              if (!isLast)
                Expanded(
                    child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: done
                          ? [
                              AppColors.success.withValues(alpha: 0.45),
                              context.divColor
                            ]
                          : [context.divColor, context.divColor],
                    ),
                  ),
                )),
            ]));
          }).toList(),
        ),
      ]),
    );
  }
}

// ── Sticky action bar ─────────────────────────────────────────────────────────
class _ActionBar extends StatelessWidget {
  final String? status;
  final VoidCallback onAccept, onReject, onStart, onComplete, onCancel;
  const _ActionBar({
    required this.status,
    required this.onAccept,
    required this.onReject,
    required this.onStart,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final l = AppLocalizations.of(context)!;

    Widget content;
    if (status == 'searching' || status == 'pending') {
      content = Row(children: [
        Expanded(
            child: _Btn(
                label: l.acceptTrip,
                icon: Icons.check_rounded,
                color: AppColors.success,
                onTap: onAccept)),
        const SizedBox(width: 10),
        Expanded(
            child: _Btn(
                label: l.reject,
                icon: Icons.close_rounded,
                color: AppColors.error,
                outlined: true,
                onTap: onReject)),
      ]);
    } else if (status == 'accepted') {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Btn(
              label: l.startTrip,
              icon: Icons.play_arrow_rounded,
              color: AppColors.primary,
              onTap: onStart),
          const SizedBox(height: 12),
          _Btn(
              label: l.cancelTrip,
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              outlined: true,
              compact: true,
              onTap: onCancel),
        ],
      );
    } else if (status == 'in_progress') {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Btn(
              label: l.completeTrip,
              icon: Icons.flag_rounded,
              color: AppColors.success,
              onTap: onComplete),
          const SizedBox(height: 12),
          _Btn(
              label: l.cancelTrip,
              icon: Icons.cancel_outlined,
              color: AppColors.error,
              outlined: true,
              compact: true,
              onTap: onCancel),
        ],
      );
    } else {
      content = const SizedBox.shrink();
    }

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
      child: content,
    );
  }
}

// ── Reusable button ───────────────────────────────────────────────────────────
class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final bool compact;
  final VoidCallback onTap;
  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: compact ? 44 : 50,
          decoration: BoxDecoration(
            gradient: outlined
                ? null
                : LinearGradient(
                    colors: [color, color.withValues(alpha: 0.75)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(14),
            border: outlined
                ? Border.all(color: color.withValues(alpha: 0.5), width: 1.2)
                : null,
            boxShadow: outlined
                ? null
                : [
                    BoxShadow(
                        color: color.withValues(alpha: 0.26),
                        blurRadius: 12,
                        offset: const Offset(0, 4))
                  ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: outlined ? color : AppColors.white, size: 17),
                const SizedBox(width: 7),
                Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: outlined ? color : AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    )),
              ]),
        ),
      );
}

// ── Night dialog ──────────────────────────────────────────────────────────────
class _NightDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, body, confirmLabel, cancelLabel;
  final Color confirmColor;
  final VoidCallback onConfirm;
  const _NightDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
    required this.cancelLabel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => Dialog(
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
                          color: iconColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: iconColor.withValues(alpha: 0.25))),
                      child: Icon(icon, color: iconColor, size: 20)),
                  const SizedBox(width: 14),
                  Text(title,
                      style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 14),
                Text(body,
                    style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                        height: 1.6)),
                const SizedBox(height: 24),
                Row(children: [
                  TextButton(
                    onPressed: () => context.pop(),
                    child: Text(cancelLabel,
                        style: TextStyle(
                            color: context.textSecondary,
                            fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 130,
                    child: _Btn(
                        label: confirmLabel,
                        icon: Icons.check_rounded,
                        color: confirmColor,
                        compact: true,
                        onTap: onConfirm),
                  ),
                ]),
              ]),
        ),
      );
}

class _AddStopoverDialog extends StatefulWidget {
  const _AddStopoverDialog();

  @override
  State<_AddStopoverDialog> createState() => _AddStopoverDialogState();
}

class _AddStopoverDialogState extends State<_AddStopoverDialog> {
  final _addressCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchAndAdd() async {
    final l = AppLocalizations.of(context)!;
    final cubit = context.read<TripRouteCubit>();
    final query = _addressCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        if (mounted) {
          AppToast.error(l.placeNotFoundDetailed);
        }
        return;
      }
      final lat = locations.first.latitude;
      final lng = locations.first.longitude;

      await cubit.addStopover(
        lat: lat,
        lng: lng,
        address: query,
      );
      if (!mounted) return;
      Navigator.pop(context);
      AppToast.success(l.stopoverAddedSuccessfully);
    } catch (e) {
      if (mounted) {
        AppToast.error(l.errorWithDetails(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      backgroundColor: context.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(l.addStopover,
          style: TextStyle(
              color: AppColors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _addressCtrl,
            style: TextStyle(color: AppColors.white),
            decoration: InputDecoration(
              hintText: l.searchPlaceHint,
              hintStyle: TextStyle(color: context.textSecondary),
              filled: true,
              fillColor: context.cardColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel, style: TextStyle(color: context.textSecondary)),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary)),
          )
        else
          TextButton(
            onPressed: _searchAndAdd,
            child: Text(l.addStopover,
                style: TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
