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
import 'package:flutter/scheduler.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/constants/map_styles.dart';
import '../../../trips/presentation/bloc/trip_route_cubit.dart';
import 'package:snapix/core/theme/app_colors.dart';
import '../../../../core/utils/map_camera_utils.dart';

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
        zIndex: 2,
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
      debugPrint('⚠️ Failed to load car icon: $e');
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
      zIndex: 2,
    );
  }

  Future<void> _animateTo(double lat, double lng) async {
    try {
      if (_mapController == null) return;

      final state = context.read<TrackingBloc>().state;
      if (state is TrackingLoaded) {
        final status = state.trip['status'];
        final isHeadingToDest = status == 'in_progress';

        final targetLat =
            (state.trip[isHeadingToDest ? 'destination_lat' : 'pickup_lat']
                    as num?)
                ?.toDouble();
        final targetLng =
            (state.trip[isHeadingToDest ? 'destination_lng' : 'pickup_lng']
                    as num?)
                ?.toDouble();

        if (targetLat != null &&
            targetLng != null &&
            targetLat != 0.0 &&
            targetLng != 0.0) {
          if ((lat - targetLat).abs() < 0.0001 &&
              (lng - targetLng).abs() < 0.0001) {
            await _mapController!.animateCamera(
                CameraUpdate.newLatLngZoom(LatLng(lat, lng), 17));
            return;
          }

          await MapCameraUtils.fitCameraToPoints(
            _mapController!,
            [
              LatLng(lat, lng),
              LatLng(targetLat, targetLng),
            ],
            padding: 96,
          );
          return;
        }
      }

      // Fallback: just center on driver if target is unknown
      await _mapController!
          .animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
    } catch (e) {
      debugPrint('⚠️ TrackingScreen: animateCamera failed: $e');
    }
  }

  // ─── Simulator route command printer ────────────────────────────────────
  bool _routeCommandPrinted = false;

  void _printSimulatorRouteCommand(List<LatLng> routePoints) {
    if (_routeCommandPrinted || routePoints.isEmpty) return;
    _routeCommandPrinted = true;

    final deviceId =
        '4974EF7A-D797-4988-947C-C06ED3D50A7E'; // ← replace with your simulator UDID
    final buffer = StringBuffer();
    buffer
        .write('xcrun simctl location $deviceId start --speed=50 --interval=1');

    for (final point in routePoints) {
      buffer.write(' ${point.latitude},${point.longitude}');
    }

    // Use print() — single line, no truncation, no "flutter:" splitting
    print(buffer.toString());
  }

  // ── color tokens (matches trip_details) ─────────────────────────────────
  static const _bg = AppColors.background;
  static const _sheet = AppColors.primarySurface;
  static const _card = AppColors.surface;
  static const _elevated = AppColors.surfaceElevated;
  static const _border = AppColors.divider;
  static const _blue = AppColors.primary;
  static const _emerald = AppColors.secondary;
  static const _rose = AppColors.error;
  static const _amber = AppColors.warning;
  static const _t1 = AppColors.textPrimary;
  static const _t2 = AppColors.textSecondary;
  static const _t3 = AppColors.textDisabled;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlocListener<TrackingBloc, TrackingState>(
        listener: (context, state) {
          if (state is TrackingLoaded) {
            final tripStatus = state.trip['status'] as String?;

            // ─── Print xcrun simctl location command for route simulation ───
            _printSimulatorRouteCommand(state.routePoints);

            // Only update map/marker when we are NOT about to navigate away.
            // Updating _driverMarkerNotifier (ValueNotifier) marks semantics
            // parentData dirty; if we immediately call context.go() in the
            // same frame the widget tree is torn down before Flutter can flush
            // semantics, triggering `!semantics.parentDataDirty` assertion.
            if (tripStatus != 'completed' && tripStatus != 'cancelled') {
              final loc = state.driverLocation;
              if (loc != null) {
                _animateTo(loc.latitude, loc.longitude);
                _updateDriverPosition(LatLng(loc.latitude, loc.longitude));
              }
            }

            if (tripStatus == 'completed') {
              // Defer navigation to after the current frame so Flutter can
              // finish semantics flush on the existing tree first.
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
          backgroundColor: _bg,
          body: Builder(builder: (context) {
            final state = context.watch<TrackingBloc>().state;
            if (state is TrackingLoading || state is TrackingInitial) {
              return _buildSkeleton(context);
            }
            if (state is TrackingError)
              return _buildError(context, state.message);
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
      Container(height: h * 0.55, color: _card),
      Expanded(
          child: Container(
        color: _sheet,
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(
              height: 28,
              width: 160,
              decoration: BoxDecoration(
                  color: _elevated, borderRadius: BorderRadius.circular(14))),
          const SizedBox(height: 20),
          Container(
              height: 80,
              decoration: BoxDecoration(
                  color: _elevated, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 12),
          Container(
              height: 80,
              decoration: BoxDecoration(
                  color: _elevated, borderRadius: BorderRadius.circular(16))),
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
                border: Border.all(color: _rose.withValues(alpha: 0.3)),
                color: _rose.withValues(alpha: 0.08)),
            child: const Icon(Icons.cloud_off_rounded, size: 40, color: _rose)),
        const SizedBox(height: 24),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _t2, fontSize: 14, height: 1.6)),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () =>
              context.read<TrackingBloc>().add(LoadTripTracking(widget.tripId)),
          child: Container(
              height: 50,
              decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_blue, AppColors.primaryDark]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: _blue.withValues(alpha: 0.3),
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
    _scheduleRouteBoundsFit(state);
    // Ensure driver marker is visible as soon as we have a location
    if (state.driverLocation != null) {
      final loc = state.driverLocation!;
      final locLatLng = LatLng(loc.latitude, loc.longitude);
      if (_targetDriverPosition == null) {
        // First time — place immediately, avoid setState-during-build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateDriverPosition(locLatLng);
          _animateTo(loc.latitude, loc.longitude);
        });
      } else if (_targetDriverPosition != locLatLng) {
        // Location changed — update without addPostFrameCallback (called from listener)
        _targetDriverPosition = locLatLng;
      }
    }

    // Static markers (pickup & destination) — never change during session
    final staticMarkers = <Marker>{};
    final polylines = <Polyline>{};

    final pickupLat = state.trip['pickup_lat'];
    final pickupLng = state.trip['pickup_lng'];
    final destLat = state.trip['destination_lat'];
    final destLng = state.trip['destination_lng'];

    if (pickupLat != null && pickupLng != null) {
      staticMarkers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(
            (pickupLat as num).toDouble(), (pickupLng as num).toDouble()),
        icon: _pickupIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 0.5),
        zIndex: 1,
        infoWindow:
            InfoWindow(title: AppLocalizations.of(context)!.meetingPointLabel),
      ));
    }
    if (destLat != null && destLng != null) {
      staticMarkers.add(Marker(
        markerId: const MarkerId('destination'),
        position:
            LatLng((destLat as num).toDouble(), (destLng as num).toDouble()),
        icon: _destIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 0.5),
        zIndex: 1,
        infoWindow:
            InfoWindow(title: AppLocalizations.of(context)!.destination),
      ));
    }
    // ── Waypoint markers are built reactively inside BlocBuilder below ──
    if (state.routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route_bg'),
        points: state.routePoints,
        color: _blue.withValues(alpha: 0.25),
        width: 12,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 0,
      ));
      polylines.add(Polyline(
        polylineId: const PolylineId('route_fg'),
        points: state.routePoints,
        color: _blue,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
        zIndex: 1,
      ));
    }

    final screenH = MediaQuery.of(context).size.height;
    final mapH = screenH * 0.55;
    final tripStatus = state.trip['status'] as String?;
    final l = AppLocalizations.of(context)!;

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
            for (int i = 0; i < activeStopovers.length; i++) {
              final wp = activeStopovers[i];
              waypointMarkers.add(Marker(
                markerId: MarkerId('wp_$i'),
                position: LatLng(wp.lat, wp.lng),
                icon: _waypointIcon ??
                    BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange),
                anchor: const Offset(0.5, 0.5),
                zIndex: 1,
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
                    return GoogleMap(
                      initialCameraPosition: _defaultCamera,
                      onMapCreated: (ctrl) {
                        _mapController = ctrl;
                        _fitBounds(ctrl, state);
                      },
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 70,
                        bottom: (screenH - mapH) + 20,
                      ),
                      markers: allMarkers,
                      polylines: polylines,
                      style: kDarkMapStyle,
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
                        _bg.withValues(alpha: 0.88)
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
                  onTap: () async {
                    setState(() => _is3DMode = !_is3DMode);
                    if (_mapController != null &&
                        state.driverLocation != null) {
                      await _mapController!.animateCamera(
                        CameraUpdate.newCameraPosition(
                          CameraPosition(
                            target: state.driverLocation!,
                            zoom: _is3DMode ? 18 : 16,
                            tilt: _is3DMode ? 60 : 0,
                            bearing: _driverRotation,
                          ),
                        ),
                      );
                    }
                  },
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
          onTap: () {
            if (_mapController != null && state.driverLocation != null) {
              _mapController!.animateCamera(CameraUpdate.newCameraPosition(
                CameraPosition(target: state.driverLocation!, zoom: 16),
              ));
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
          decoration: const BoxDecoration(
            color: _sheet,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: _border, borderRadius: BorderRadius.circular(2)),
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
                    _buildRouteCard(context, state.trip, l),
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
                                color: _rose.withValues(alpha: 0.5),
                                width: 1.2),
                          ),
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cancel_outlined,
                                    color: _rose, size: 17),
                                const SizedBox(width: 7),
                                Text(l.cancelTrip,
                                    style: const TextStyle(
                                        color: _rose,
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

  void _scheduleRouteBoundsFit(TrackingLoaded state) {
    if (_mapController == null || state.routePoints.isEmpty) return;
    final first = state.routePoints.first;
    final last = state.routePoints.last;
    final signature =
        '${state.routePoints.length}:${first.latitude.toStringAsFixed(5)},'
        '${first.longitude.toStringAsFixed(5)}:${last.latitude.toStringAsFixed(5)},'
        '${last.longitude.toStringAsFixed(5)}';
    if (_lastRouteBoundsSignature == signature) return;
    _lastRouteBoundsSignature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctrl = _mapController;
      if (!mounted || ctrl == null) return;
      _fitBounds(ctrl, state);
    });
  }

  Widget _statusPill(String? status, AppLocalizations l) {
    final color = switch (status) {
      'completed' => _emerald,
      'cancelled' => _rose,
      'in_progress' || 'accepted' => _blue,
      'searching' => _amber,
      _ => _t2,
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
        color: _sheet.withValues(alpha: 0.95),
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

  Widget _buildRouteCard(
      BuildContext context, Map<String, dynamic> trip, AppLocalizations l) {
    final pickup = trip['meeting_address'] ?? trip['pickup_address'] ?? '';
    final dest = trip['destination_address'] ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1),
      ),
      child: Row(children: [
        // Destination (left side)
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l.destination.toUpperCase(),
              style: const TextStyle(
                  color: _blue,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(dest.isEmpty ? '---' : dest,
              style: const TextStyle(
                  color: _t1,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ])),
        // Arrow
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: const Icon(Icons.arrow_back_rounded, color: _t3, size: 16),
        ),
        // Pickup (right side)
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(l.meetingPointLabel.toUpperCase(),
              style: const TextStyle(
                  color: _emerald,
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5)),
          const SizedBox(height: 6),
          Text(pickup.isEmpty ? '---' : pickup,
              style: const TextStyle(
                  color: _t1,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end),
        ])),
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
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1),
      ),
      child: Row(children: [
        // Location center button
        _buildActionIcon(Icons.my_location_rounded, _amber, () {
          if (_mapController != null && state.driverLocation != null) {
            _mapController!.animateCamera(CameraUpdate.newCameraPosition(
              CameraPosition(target: state.driverLocation!, zoom: 16),
            ));
          }
        }),
        // Phone button
        if (phone != null) ...[
          const SizedBox(width: 8),
          _buildActionIcon(Icons.phone_rounded, _emerald, () {}),
        ],
        // Chat button
        const SizedBox(width: 8),
        _buildActionIcon(Icons.chat_bubble_rounded, _blue, () {
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
              style: const TextStyle(
                  color: _t1, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            const Icon(Icons.star_rounded, color: _amber, size: 13),
            const SizedBox(width: 3),
            Text(rating,
                style: const TextStyle(
                    color: _amber, fontSize: 11, fontWeight: FontWeight.w700)),
          ]),
        ])),
        const SizedBox(width: 12),
        // Avatar
        Stack(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_blue, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: _elevated,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: const TextStyle(
                          color: _blue,
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
                      color: _emerald,
                      shape: BoxShape.circle,
                      border: Border.all(color: _card, width: 2)))),
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
        backgroundColor: _card,
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
                    color: _rose.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: _rose.withValues(alpha: 0.25)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded,
                      color: _rose, size: 20),
                ),
                const SizedBox(width: 14),
                Text(l.cancelTrip,
                    style: const TextStyle(
                        color: _t1, fontSize: 17, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 14),
              Text(l.areYouSureCancelTrip,
                  style:
                      const TextStyle(color: _t2, fontSize: 14, height: 1.6)),
              const SizedBox(height: 24),
              Row(children: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(l.noLabel,
                      style: const TextStyle(
                          color: _t2, fontWeight: FontWeight.w600)),
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
                        colors: [_rose, _rose.withValues(alpha: 0.75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                            color: _rose.withValues(alpha: 0.26),
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
    final vType = trip['vehicle_type'] as String? ?? 'car';
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
                color: _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border, width: 1),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.fareDetails.toUpperCase(),
                        style: const TextStyle(
                            color: _t3,
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
                          '${price.toStringAsFixed(0)} ${l.currencySar}',
                          style: const TextStyle(
                            color: _t3,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.lineThrough,
                            decorationColor: _t3,
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
                            Text(finalPrice.toStringAsFixed(0),
                                style: const TextStyle(
                                    color: _t1,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                    height: 1)),
                            const SizedBox(width: 4),
                            Text(l.currencySar,
                                style: const TextStyle(
                                    color: _t2,
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
                              '-${couponDiscount.toStringAsFixed(0)} ${l.currencySar}',
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
                            Text(price.toStringAsFixed(0),
                                style: const TextStyle(
                                    color: _t1,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                    height: 1)),
                            const SizedBox(width: 4),
                            Text(l.currencySar,
                                style: const TextStyle(
                                    color: _t2,
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
                            ? _emerald.withValues(alpha: 0.1)
                            : _amber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: isPaid
                                ? _emerald.withValues(alpha: 0.28)
                                : _amber.withValues(alpha: 0.28)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                                color: isPaid ? _emerald : _amber,
                                shape: BoxShape.circle)),
                        const SizedBox(width: 5),
                        Text(isPaid ? l.paid : l.unpaid,
                            style: TextStyle(
                                color: isPaid ? _emerald : _amber,
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
                color: _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _border, width: 1),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.tripDetails.toUpperCase(),
                        style: const TextStyle(
                            color: _t3,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 12),
                    _buildStatItem(
                        Icons.straighten_rounded, _blue, '$dist ${l.km}'),
                    const SizedBox(height: 8),
                    _buildStatItem(
                        Icons.directions_car_rounded, AppColors.purple, vName),
                    const SizedBox(height: 8),
                    _buildStatItem(
                      pay == 'cash'
                          ? Icons.payments_rounded
                          : Icons.credit_card_rounded,
                      _amber,
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
              style: const TextStyle(
                  color: _t1, fontSize: 11, fontWeight: FontWeight.w600))),
    ]);
  }

  void _fitBounds(GoogleMapController ctrl, TrackingLoaded state) {
    final points = <LatLng>[];
    if (state.driverLocation != null &&
        state.driverLocation!.latitude != 0.0 &&
        state.driverLocation!.longitude != 0.0) {
      points.add(LatLng(
          state.driverLocation!.latitude, state.driverLocation!.longitude));
    }
    if (state.trip['pickup_lat'] != null &&
        state.trip['pickup_lng'] != null &&
        state.trip['pickup_lat'] != 0.0 &&
        state.trip['pickup_lng'] != 0.0) {
      points.add(LatLng(
        (state.trip['pickup_lat'] as num).toDouble(),
        (state.trip['pickup_lng'] as num).toDouble(),
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
      padding: 96,
      delay: const Duration(milliseconds: 400),
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
            color: AppColors.primarySurface.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.divider, width: 1),
            boxShadow: [
              BoxShadow(
                  color: AppColors.black.withValues(alpha: 0.38),
                  blurRadius: 10)
            ],
          ),
          child: Icon(icon, color: AppColors.textPrimary, size: 18),
        ),
      );
}
