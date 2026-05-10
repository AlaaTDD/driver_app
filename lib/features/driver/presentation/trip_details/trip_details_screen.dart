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
import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/map_styles.dart';
import '../../../../services/directions_service.dart';
import '../../../../services/location_service.dart';
import '../../../../core/constants/env_constants.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:ui' as ui;

// ─── Design Tokens (shared palette) ──────────────────────────────────────────
class _C {
  static const bg       = Color(0xFF0D0F18);
  static const sheet    = Color(0xFF12151F);
  static const card     = Color(0xFF181C2A);
  static const elevated = Color(0xFF1E2336);
  static const border   = Color(0xFF252A3D);

  static const blue     = Color(0xFF4C8BF5);
  static const blueGlow = Color(0x404C8BF5);
  static const emerald  = Color(0xFF1FC87A);
  static const rose     = Color(0xFFFF4060);
  static const amber    = Color(0xFFF5A524);
  static const violet   = Color(0xFF8B5CF6);

  static const t1       = Color(0xFFEEF0FF);
  static const t2       = Color(0xFF7B82A3);
  static const t3       = Color(0xFF3A4060);
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class DriverTripDetailsScreen extends StatefulWidget {
  final String tripId;
  const DriverTripDetailsScreen({super.key, required this.tripId});

  @override
  State<DriverTripDetailsScreen> createState() => _DriverTripDetailsScreenState();
}

class _DriverTripDetailsScreenState extends State<DriverTripDetailsScreen>
    with TickerProviderStateMixin {
  // map
  final Completer<GoogleMapController> _mapController = Completer();
  List<LatLng> _routePoints = [];
  bool _routeFetchRequested = false;

  // driver location
  StreamSubscription<Position>? _locationSub;
  LatLng? _driverLocation;
  BitmapDescriptor? _carIcon;
  double _driverHeading = 0.0;
  bool _cameraFollowing = false;

  final ValueNotifier<Marker?> _driverMarkerNotifier = ValueNotifier<Marker?>(null);
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
    _sheetCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
    _shimCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();

    _sheetAnim = CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOutExpo);
    _fadeAnim  = CurvedAnimation(parent: _sheetCtrl, curve: Curves.easeOut);
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

  Future<void> _loadCircleIcons() async {
    _pickupIcon = await _createCircleMarker(_C.emerald);
    _destIcon = await _createCircleMarker(_C.rose);
    if (mounted) setState(() {});
  }

  Future<BitmapDescriptor> _createCircleMarker(Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint()..color = color;
    
    final outerPaint = Paint()..color = color.withOpacity(0.2);
    canvas.drawCircle(const Offset(20, 20), 18, outerPaint);
    canvas.drawCircle(const Offset(20, 20), 10, paint);
    
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(20, 20), 5, whitePaint);
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(40, 40);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  Future<void> _loadCarIcon() async {
    try {
      final data  = await rootBundle.load('assets/images/carr.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 40);
      final frame = await codec.getNextFrame();
      final resized = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (resized != null && mounted) {
        setState(() => _carIcon = BitmapDescriptor.bytes(resized.buffer.asUint8List()));
        if (_animatedDriverPosition != null) {
          _updateDriverPosition(_animatedDriverPosition!);
        }
      }
    } catch (e) {
      debugPrint('⚠️ car icon: $e');
    }
  }

  void _startLocationTracking() {
    _locationSub = LocationService.instance.getLocationStream().listen((pos) async {
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _driverLocation = loc;
        _driverHeading  = pos.heading;
      });
      _updateDriverPosition(loc);
      if (_cameraFollowing && _mapController.isCompleted) {
        final ctrl = await _mapController.future;
        ctrl.animateCamera(CameraUpdate.newCameraPosition(
          CameraPosition(target: _driverLocation!, zoom: 16, bearing: _driverHeading),
        ));
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
      icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      anchor: const Offset(0.5, 0.5),
      flat: true,
      zIndex: 2,
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
      if (prev.latitude == target.latitude && prev.longitude == target.longitude) return;
      
      final newLat = prev.latitude + (target.latitude - prev.latitude) * 0.12;
      final newLng = prev.longitude + (target.longitude - prev.longitude) * 0.12;
      _animatedDriverPosition = LatLng(newLat, newLng);

      _driverMarkerNotifier.value = Marker(
        markerId: const MarkerId('driver'),
        position: _animatedDriverPosition!,
        rotation: _driverRotation,
        icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndex: 2,
      );
    });
    _animationTicker?.start();
  }

  Future<void> _fetchRoute(double oLat, double oLng, double dLat, double dLng) async {
    final result = await DirectionsService.getRoute(
      originLat: oLat, originLng: oLng, destLat: dLat, destLng: dLng,
      apiKey: EnvConstants.googleMapsApiKey,
    );
    if (!mounted || result == null) return;
    setState(() => _routePoints = result.points);
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
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: BlocConsumer<TripDetailsBloc, TripDetailsState>(
          listener: (ctx, state) {
            if (state is TripDetailsLoaded) {
              final status = state.trip['status'] as String?;
              if (status == 'completed') {
                _toast(ctx, AppLocalizations.of(ctx)!.tripCompleted, ok: true);
                context.go('${AppRoutes.driverRating}?tripId=${widget.tripId}');
              }
              // snap camera to pickup
              final pLat = (state.trip['pickup_lat'] as num?)?.toDouble();
              final pLng = (state.trip['pickup_lng'] as num?)?.toDouble();
              if (pLat != null && _mapController.isCompleted) {
                _mapController.future.then((c) => c.animateCamera(
                    CameraUpdate.newLatLng(LatLng(pLat, pLng!))));
              }
              _sheetCtrl.forward(from: 0);
            } else if (state is TripDetailsError) {
              _toast(ctx, state.message, ok: false);
            }
          },
          builder: (ctx, state) {
            if (state is TripDetailsLoading || state is TripDetailsInitial) return _skeleton();
            if (state is TripDetailsError) return _errorView(state.message);
            if (state is TripDetailsLoaded) return _body(state.trip);
            return _skeleton();
          },
        ),
      ),
    );
  }

  void _toast(BuildContext ctx, String msg, {required bool ok}) {
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, color: Colors.white))),
      ]),
      backgroundColor: ok ? _C.emerald : _C.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      duration: const Duration(seconds: 2),
      elevation: 0,
    ));
  }

  // ══════════════════════════════════════════════════════════
  // SKELETON
  // ══════════════════════════════════════════════════════════
  Widget _skeleton() {
    return AnimatedBuilder(
      animation: _shimCtrl,
      builder: (_, __) {
        final t = (_shimCtrl.value * 2 - 1).abs();
        Color sh(Color b) => Color.lerp(b, _C.elevated, t)!;
        return Column(children: [
          Container(height: MediaQuery.of(context).size.height * 0.45, color: sh(_C.card)),
          Expanded(
            child: Container(
              color: _C.sheet,
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
    );
  }

  Widget _sBox(Color Function(Color) sh, {required double h, double? w}) => Container(
      height: h, width: w,
      decoration: BoxDecoration(color: sh(_C.card), borderRadius: BorderRadius.circular(14)));

  // ══════════════════════════════════════════════════════════
  // ERROR
  // ══════════════════════════════════════════════════════════
  Widget _errorView(String msg) {
    final l = AppLocalizations.of(context)!;
    return SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 88, height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _C.rose.withValues(alpha: 0.3)),
            color: _C.rose.withValues(alpha: 0.08),
          ),
          child: const Icon(Icons.cloud_off_rounded, size: 40, color: _C.rose),
        ),
        const SizedBox(height: 24),
        Text(msg, textAlign: TextAlign.center,
            style: const TextStyle(color: _C.t2, fontSize: 14, height: 1.6)),
        const SizedBox(height: 32),
        _Btn(
          label: l.retry, icon: Icons.refresh_rounded, color: _C.blue,
          onTap: () => context.read<TripDetailsBloc>().add(LoadTripDetails(widget.tripId)),
        ),
      ]),
    )));
  }

  // ══════════════════════════════════════════════════════════
  // MAIN BODY
  // ══════════════════════════════════════════════════════════
  Widget _body(Map<String, dynamic> trip) {
    final status   = trip['status'] as String?;
    final screenH  = MediaQuery.of(context).size.height;
    final mapH     = screenH * 0.44;
    final pLat     = (trip['pickup_lat']      as num?)?.toDouble();
    final pLng     = (trip['pickup_lng']      as num?)?.toDouble();
    final dLat     = (trip['destination_lat'] as num?)?.toDouble();
    final dLng     = (trip['destination_lng'] as num?)?.toDouble();
    final hasAction = _hasAction(status);

    return Stack(children: [

      // ── [1] Map
      Positioned.fill(
        child: _buildMap(trip, pLat, pLng, dLat, dLng, screenH - mapH),
      ),

      // ── [2] Header (Back button & Status pill)
      Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MapCircleBtn(icon: Icons.arrow_back_ios_new_rounded, onTap: () => context.pop()),
                Expanded(
                  child: Center(child: _statusPill(status)),
                ),
                const SizedBox(width: 42), // Balance the row
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
          icon: _cameraFollowing ? Icons.my_location_rounded : Icons.location_searching_rounded,
          onTap: () async {
            setState(() => _cameraFollowing = true);
            if (_driverLocation != null && _mapController.isCompleted) {
              final ctrl = await _mapController.future;
              ctrl.animateCamera(CameraUpdate.newCameraPosition(
                CameraPosition(target: _driverLocation!, zoom: 16, bearing: _driverHeading),
              ));
            }
          },
        ),
      ),

      // ── [4] Sliding bottom sheet
      Positioned(
        top: mapH - 12, left: 0, right: 0, bottom: 0,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.14), end: Offset.zero)
              .animate(_sheetAnim),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Container(
              decoration: const BoxDecoration(
                color: _C.sheet,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [
                // handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: _C.border, borderRadius: BorderRadius.circular(2)),
                ),
                Expanded(child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                    // User card
                    if (trip['user'] != null) ...[
                      _UserStrip(user: trip['user'] as Map, tripId: widget.tripId),
                      const SizedBox(height: 13),
                    ],

                    // Route ticket
                    _RouteTicket(trip: trip),
                    const SizedBox(height: 13),

                    // Price + Stats
                    IntrinsicHeight(child: Row(
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

                    SizedBox(height: hasAction ? 90 : 20),
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
          left: 0, right: 0, bottom: 0,
          child: FadeTransition(
            opacity: _fadeAnim,
            child: _ActionBar(
              status: status,
              onAccept:   () => context.read<TripDetailsBloc>().add(AcceptTrip(widget.tripId)),
              onReject:   () => _rejectDialog(),
              onStart:    () => context.read<TripDetailsBloc>().add(StartTrip(widget.tripId)),
              onComplete: () => _completeDialog(),
            ),
          ),
        ),
    ]);
  }

  bool _hasAction(String? s) =>
      {'searching', 'pending', 'accepted', 'in_progress'}.contains(s);

  // ── Map ────────────────────────────────────────────────────────────────────
  Widget _buildMap(Map<String, dynamic> trip, double? pLat, double? pLng, double? dLat, double? dLng, double bottomPadding) {
    final markers   = <Marker>{};
    final polylines = <Polyline>{};
    final l = AppLocalizations.of(context)!;

    if (pLat != null && pLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pLat, pLng),
        icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: trip['pickup_address'] as String? ?? l.meetingPointLabel),
      ));
    }
    if (dLat != null && dLng != null) {
      markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: LatLng(dLat, dLng),
        icon: _destIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: trip['destination_address'] as String? ?? l.destination),
      ));
    }


    // fetch route once
    if (pLat != null && pLng != null && dLat != null && dLng != null && !_routeFetchRequested) {
      _routeFetchRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) =>
          _fetchRoute(pLat, pLng, dLat, dLng));
    }
    if (_routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: _C.blue,
        width: 4,
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
          return GoogleMap(
            initialCameraPosition: CameraPosition(target: initTarget, zoom: 15),
            style: kDarkMapStyle,
            minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 70,
              bottom: bottomPadding + 20,
            ),
            onMapCreated: (ctrl) {
              if (!_mapController.isCompleted) _mapController.complete(ctrl);
              if (_driverLocation != null && _cameraFollowing) {
                ctrl.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(target: _driverLocation!, zoom: 16, bearing: _driverHeading),
                ));
              } else {
                _fitMapBounds(ctrl, markers);
              }
            },
            onCameraMoveStarted: () => setState(() => _cameraFollowing = false),
            markers: allMarkers,
            polylines: polylines,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            compassEnabled: false,
          );
        },
      ),
      // bottom fade
      Positioned(
        bottom: 0, left: 0, right: 0, height: 80,
        child: DecoratedBox(decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, _C.bg.withValues(alpha: 0.88)],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
        )),
      ),
    ]);
  }

  void _fitMapBounds(GoogleMapController ctrl, Set<Marker> markers) {
    final pts = markers.map((m) => m.position).where((p) => p.latitude != 0.0 && p.longitude != 0.0).toList();
    if (_driverLocation != null && _driverLocation!.latitude != 0.0 && _driverLocation!.longitude != 0.0) {
      pts.add(_driverLocation!);
    }
    if (pts.isEmpty) return;
    if (pts.length == 1) {
      Future.delayed(const Duration(milliseconds: 400), () =>
          ctrl.animateCamera(CameraUpdate.newLatLngZoom(pts.first, 15)));
      return;
    }
    final sw = LatLng(pts.map((p) => p.latitude).reduce(math.min),
                      pts.map((p) => p.longitude).reduce(math.min));
    final ne = LatLng(pts.map((p) => p.latitude).reduce(math.max),
                      pts.map((p) => p.longitude).reduce(math.max));
    Future.delayed(const Duration(milliseconds: 400), () =>
        ctrl.animateCamera(CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: sw, northeast: ne), 80)));
  }

  // ── Status pill ────────────────────────────────────────────────────────────
  Widget _statusPill(String? status) {
    final color = _statusColor(status);
    final icon  = _statusIcon(status);
    final label = _statusLabel(status);
    final live  = status == 'in_progress' || status == 'searching';

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Transform.scale(
        scale: live ? (0.97 + 0.03 * _pulseAnim.value) : 1.0,
        child: child,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: _C.sheet.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 22, spreadRadius: 2),
            const BoxShadow(color: Colors.black54, blurRadius: 10),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (live)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) => Container(
                width: 9, height: 9,
                decoration: BoxDecoration(
                  color: color, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: _pulseAnim.value), blurRadius: 8)],
                ),
              ),
            )
          else
            Icon(icon, color: color, size: 16),
          const SizedBox(width: 9),
          Text(label, style: TextStyle(color: color, fontSize: 13,
              fontWeight: FontWeight.w800, letterSpacing: 0.2)),
        ]),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────
  void _rejectDialog() {
    final l = AppLocalizations.of(context)!;
    showDialog(context: context, builder: (_) => _NightDialog(
      icon: Icons.cancel_outlined, iconColor: _C.rose,
      title: l.reject, body: l.areYouSureRejectTrip,
      confirmLabel: l.reject, confirmColor: _C.rose,
      cancelLabel: l.cancel,
      onConfirm: () {
        context.pop();
        context.read<TripDetailsBloc>().add(RejectTrip(widget.tripId));
      },
    ));
  }

  void _completeDialog() {
    final l = AppLocalizations.of(context)!;
    showDialog(context: context, builder: (_) => _NightDialog(
      icon: Icons.check_circle_outline_rounded, iconColor: _C.emerald,
      title: l.completeTrip, body: l.areYouSureCompleteTrip,
      confirmLabel: l.completeTrip, confirmColor: _C.emerald,
      cancelLabel: l.cancel,
      onConfirm: () {
        context.pop();
        context.read<TripDetailsBloc>().add(CompleteTrip(widget.tripId));
      },
    ));
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _statusColor(String? s) => switch (s) {
    'completed'               => _C.emerald,
    'cancelled'               => _C.rose,
    'in_progress' || 'accepted' => _C.blue,
    'searching' || 'pending'  => _C.amber,
    _                         => _C.t2,
  };

  IconData _statusIcon(String? s) => switch (s) {
    'completed'   => Icons.check_circle_rounded,
    'cancelled'   => Icons.cancel_rounded,
    'in_progress' => Icons.local_taxi_rounded,
    'accepted'    => Icons.thumb_up_rounded,
    'searching' || 'pending' => Icons.radar_rounded,
    _             => Icons.help_outline_rounded,
  };

  String _statusLabel(String? s) {
    final l = AppLocalizations.of(context)!;
    return switch (s) {
      'completed'   => l.completed,
      'cancelled'   => l.cancelled,
      'in_progress' => l.inProgress,
      'accepted'    => l.tripAccepted,
      'searching' || 'pending' => l.searchingForDriver,
      _             => l.pending,
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
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: _C.sheet.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: _C.border, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
          ),
          child: Icon(icon, color: _C.t1, size: 18),
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
    final l         = AppLocalizations.of(context)!;
    final name      = user['name']       as String? ?? l.userDefault;
    final avatarUrl = user['avatar_url'] as String?;
    final rating    = user['rating']?.toString() ?? '0.0';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Row(children: [
        // Avatar
        Stack(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_C.violet, Color(0xFF5B21B6)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: _C.elevated,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(color: _C.violet, fontSize: 18, fontWeight: FontWeight.w800))
                  : null,
            ),
          ),
          Positioned(bottom: 1, right: 1,
            child: Container(width: 12, height: 12,
              decoration: BoxDecoration(
                color: _C.emerald, shape: BoxShape.circle,
                border: Border.all(color: _C.card, width: 2),
              ))),
        ]),
        const SizedBox(width: 12),

        // Name + rating
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: _C.t1, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.star_rounded, color: _C.amber, size: 13),
            const SizedBox(width: 3),
            Text(rating,
                style: const TextStyle(color: _C.amber, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _C.violet.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.violet.withValues(alpha: 0.25)),
              ),
              child: Text(l.passenger,
                  style: const TextStyle(color: _C.violet, fontSize: 9,
                      fontWeight: FontWeight.w700, letterSpacing: 1.0)),
            ),
          ]),
        ])),

        // Chat icon
        _CircleAction(
          icon: Icons.chat_bubble_rounded, color: _C.blue,
          onTap: () {
            final uId = user['id'] as String?;
            if (uId != null) {
              context.push('${AppRoutes.driverMessages}?tripId=$tripId&otherUserId=$uId&otherUserName=${Uri.encodeComponent(name)}');
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
  const _CircleAction({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36, height: 36,
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
    final l      = AppLocalizations.of(context)!;
    final pickup = trip['meeting_address'] ?? trip['pickup_address'] ?? '';
    final dest   = trip['destination_address'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Stack(children: [
        Positioned(left: 0, top: 0, bottom: 0,
          child: Center(child: Container(width: 5, height: 28,
            decoration: const BoxDecoration(color: _C.sheet,
              borderRadius: BorderRadius.only(
                topRight: Radius.circular(8), bottomRight: Radius.circular(8)))))),
        Positioned(right: 0, top: 0, bottom: 0,
          child: Center(child: Container(width: 5, height: 28,
            decoration: const BoxDecoration(color: _C.sheet,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)))))),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 9, height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _C.emerald,
                    boxShadow: [BoxShadow(color: _C.emerald.withValues(alpha: 0.5), blurRadius: 6)],
                  )),
                const SizedBox(width: 7),
                Text(l.meetingPointLabel.toUpperCase(),
                    style: const TextStyle(color: _C.emerald, fontSize: 8,
                        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
              ]),
              const SizedBox(height: 8),
              Text(pickup, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.t1, fontSize: 12,
                      fontWeight: FontWeight.w600, height: 1.35)),
            ])),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                ...List.generate(5, (i) => Container(
                    width: 3, height: 3, margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: i.isEven ? _C.border : Colors.transparent,
                      shape: BoxShape.circle,
                    ))),
                const SizedBox(height: 4),
                const Icon(Icons.east_rounded, color: _C.t3, size: 14),
              ]),
            ),

            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text(l.destination.toUpperCase(),
                    style: const TextStyle(color: _C.blue, fontSize: 8,
                        fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                const SizedBox(width: 7),
                Container(width: 9, height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _C.blue,
                    boxShadow: [BoxShadow(color: _C.blueGlow, blurRadius: 6)],
                  )),
              ]),
              const SizedBox(height: 8),
              Text(dest, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
                  style: const TextStyle(color: _C.t1, fontSize: 12,
                      fontWeight: FontWeight.w600, height: 1.35)),
            ])),
          ]),
        ),
      ]),
    );
  }
}

// ── Price Box ─────────────────────────────────────────────────────────────────
class _PriceBox extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _PriceBox({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l     = AppLocalizations.of(context)!;
    final price = (trip['price'] as num?)?.toDouble() ?? 0;
    final isPaid = trip['is_paid'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.fareDetails.toUpperCase(),
            style: const TextStyle(color: _C.t3, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 1.8)),
        const SizedBox(height: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(price.toStringAsFixed(0),
                  style: const TextStyle(color: _C.t1, fontSize: 44,
                      fontWeight: FontWeight.w900, letterSpacing: -2, height: 1)),
              const SizedBox(width: 5),
              Text(l.currencySar,
                  style: const TextStyle(color: _C.t2, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPaid ? _C.emerald.withValues(alpha: 0.1) : _C.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isPaid ? _C.emerald.withValues(alpha: 0.28) : _C.amber.withValues(alpha: 0.28)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6,
              decoration: BoxDecoration(
                color: isPaid ? _C.emerald : _C.amber, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(isPaid ? l.paid : l.unpaid,
                style: TextStyle(color: isPaid ? _C.emerald : _C.amber,
                    fontSize: 11, fontWeight: FontWeight.w700)),
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
    final l     = AppLocalizations.of(context)!;
    final dist  = (trip['distance_km'] as num?)?.toStringAsFixed(1) ?? '0';
    final vType = trip['vehicle_type'] as String? ?? 'car';
    final pay   = trip['payment_method'] as String? ?? 'cash';

    final vName = switch (vType) {
      'sedan' => l.sedan, 'suv' => l.suv, 'van' => l.van,
      'minibus' => l.minibus, 'motorcycle' => l.motorcycle, _ => l.car,
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.tripDetails.toUpperCase(),
            style: const TextStyle(color: _C.t3, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 1.8)),
        const SizedBox(height: 14),
        _StatRow(icon: Icons.straighten_rounded,     color: _C.blue,   label: '$dist ${l.km}'),
        const SizedBox(height: 10),
        _StatRow(icon: Icons.directions_car_rounded, color: _C.violet, label: vName),
        const SizedBox(height: 10),
        _StatRow(
          icon: pay == 'cash' ? Icons.payments_rounded : Icons.credit_card_rounded,
          color: _C.amber,
          label: pay == 'cash' ? l.cash : l.bankCard,
        ),
      ]),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   label;
  const _StatRow({required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 28, height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 14)),
        const SizedBox(width: 10),
        Flexible(child: Text(label,
            style: const TextStyle(color: _C.t1, fontSize: 12, fontWeight: FontWeight.w600))),
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
      (l.tripRequest,  trip['created_at'],   true),
      (l.acceptTrip,   trip['accepted_at'],  trip['accepted_at']  != null),
      (l.startTrip,    trip['started_at'],   trip['started_at']   != null),
      (l.completeTrip, trip['completed_at'], trip['completed_at'] != null),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.timeline.toUpperCase(),
            style: const TextStyle(color: _C.t3, fontSize: 9,
                fontWeight: FontWeight.w800, letterSpacing: 1.8)),
        const SizedBox(height: 18),
        Row(
          children: steps.asMap().entries.map((e) {
            final i    = e.key;
            final s    = e.value;
            final done = s.$3 as bool;
            final isLast = i == steps.length - 1;
            String t = '';
            final raw = s.$2;
            if (raw != null) {
              try {
                final dt = DateTime.parse(raw.toString()).toLocal();
                t = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              } catch (_) {}
            }

            return Expanded(child: Row(children: [
              Expanded(child: Column(children: [
                Container(width: 18, height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? _C.emerald : _C.elevated,
                    border: done ? null : Border.all(color: _C.border, width: 1.5),
                    boxShadow: done
                        ? [BoxShadow(color: _C.emerald.withValues(alpha: 0.4), blurRadius: 8)]
                        : null,
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 11)
                      : null,
                ),
                const SizedBox(height: 7),
                Text(s.$1, textAlign: TextAlign.center, maxLines: 2,
                    style: TextStyle(
                      color: done ? _C.t1 : _C.t3, fontSize: 9.5,
                      fontWeight: done ? FontWeight.w600 : FontWeight.w400, height: 1.3,
                    )),
                if (t.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(t, style: const TextStyle(color: _C.emerald, fontSize: 9.5,
                      fontWeight: FontWeight.w700)),
                ],
              ])),
              if (!isLast)
                Expanded(child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 28),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: done
                          ? [_C.emerald.withValues(alpha: 0.45), _C.border]
                          : [_C.border, _C.border],
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
  final VoidCallback onAccept, onReject, onStart, onComplete;
  const _ActionBar({
    required this.status,
    required this.onAccept, required this.onReject,
    required this.onStart, required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final l = AppLocalizations.of(context)!;

    Widget content;
    if (status == 'searching' || status == 'pending') {
      content = Row(children: [
        Expanded(child: _Btn(label: l.acceptTrip, icon: Icons.check_rounded,
            color: _C.emerald, onTap: onAccept)),
        const SizedBox(width: 10),
        Expanded(child: _Btn(label: l.reject, icon: Icons.close_rounded,
            color: _C.rose, outlined: true, onTap: onReject)),
      ]);
    } else if (status == 'accepted') {
      content = _Btn(label: l.startTrip, icon: Icons.play_arrow_rounded,
          color: _C.blue, onTap: onStart);
    } else if (status == 'in_progress') {
      content = _Btn(label: l.completeTrip, icon: Icons.flag_rounded,
          color: _C.emerald, onTap: onComplete);
    } else {
      content = const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(18, 12, 18, 12 + bottom),
      decoration: BoxDecoration(
        color: _C.sheet,
        border: const Border(top: BorderSide(color: _C.border, width: 1)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, -4))],
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
    required this.label, required this.icon,
    required this.color, required this.onTap,
    this.outlined = false, this.compact = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: compact ? 44 : 50,
          decoration: BoxDecoration(
            gradient: outlined ? null : LinearGradient(
              colors: [color, color.withValues(alpha: 0.75)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: outlined ? Border.all(color: color.withValues(alpha: 0.5), width: 1.2) : null,
            boxShadow: outlined ? null
                : [BoxShadow(color: color.withValues(alpha: 0.26), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: outlined ? color : Colors.white, size: 17),
            const SizedBox(width: 7),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: outlined ? color : Colors.white,
                  fontSize: 12, fontWeight: FontWeight.w700,
                ))),
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
    required this.icon, required this.iconColor,
    required this.title, required this.body,
    required this.confirmLabel, required this.confirmColor,
    required this.cancelLabel, required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withValues(alpha: 0.25))),
                  child: Icon(icon, color: iconColor, size: 20)),
                const SizedBox(width: 14),
                Text(title, style: const TextStyle(color: _C.t1, fontSize: 17,
                    fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 14),
              Text(body, style: const TextStyle(color: _C.t2, fontSize: 14, height: 1.6)),
              const SizedBox(height: 24),
              Row(children: [
                TextButton(
                  onPressed: () => context.pop(),
                  child: Text(cancelLabel,
                      style: const TextStyle(color: _C.t2, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                _Btn(label: confirmLabel, icon: Icons.check_rounded,
                    color: confirmColor, compact: true, onTap: onConfirm),
              ]),
            ]),
        ),
      );
}