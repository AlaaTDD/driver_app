import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/constants/map_styles.dart';
import '../../../../core/constants/env_constants.dart';
import '../../../../services/directions_service.dart';
import '../trips/bloc/trips_bloc.dart';
import '../trips/bloc/trips_event.dart';
import '../trips/bloc/trips_state.dart';


// ─── Design Tokens ────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF0D0F18);
  static const sheet = Color(0xFF12151F);
  static const card = Color(0xFF181C2A);
  static const elevated = Color(0xFF1E2336);
  static const border = Color(0xFF252A3D);

  static const blue = Color(0xFF4C8BF5);
  static const blueGlow = Color(0x404C8BF5);
  static const emerald = Color(0xFF1FC87A);
  static const rose = Color(0xFFFF4060);
  static const amber = Color(0xFFF5A524);
  static const violet = Color(0xFF8B5CF6);

  static const t1 = Color(0xFFEEF0FF);
  static const t2 = Color(0xFF7B82A3);
  static const t3 = Color(0xFF3A4060);
}

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
  Map<String, dynamic>? _trip;

  // Route / polyline state
  List<LatLng> _routePoints = [];
  bool _routeFetchRequested = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destIcon;

  Future<void> _loadCircleIcons() async {
    _pickupIcon = await _createCircleMarker(Colors.green);
    _destIcon = await _createCircleMarker(Colors.red);
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

  void _load({bool silent = false}) {
    _loadCircleIcons();
    _animationTriggered = false;
    _routeFetchRequested = false;
    _routePoints = [];
    context.read<TripsBloc>().add(LoadTripDetails(widget.tripId, silent: silent));
  }

  Future<void> _fetchRoute(
      double oLat, double oLng, double dLat, double dLng) async {
    final result = await DirectionsService.getRoute(
      originLat: oLat,
      originLng: oLng,
      destLat: dLat,
      destLng: dLng,
      apiKey: EnvConstants.googleMapsApiKey,
    );
    if (!mounted || result == null) return;
    setState(() => _routePoints = result.points);
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    _pulseCtrl.dispose();
    _shimCtrl.dispose();
    _mapCtrl?.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  bool _animationTriggered = false;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _C.bg,
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
                WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _sheetCtrl.forward(from: 0));
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
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(
            child: Text(msg,
                style: const TextStyle(fontSize: 13, color: Colors.white))),
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
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _shimCtrl,
        builder: (_, __) {
          final t = (_shimCtrl.value * 2 - 1).abs();
          Color sh(Color b) => Color.lerp(b, _C.elevated, t)!;
        return Column(children: [
          Container(
              height: MediaQuery.of(context).size.height * 0.45,
              color: sh(_C.card)),
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
      ),
    );
  }

  Widget _sBox(Color Function(Color) sh, {required double h, double? w}) =>
      Container(
          height: h,
          width: w,
          decoration: BoxDecoration(
              color: sh(_C.card), borderRadius: BorderRadius.circular(14)));

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
            border: Border.all(color: _C.rose.withValues(alpha: 0.3)),
            color: _C.rose.withValues(alpha: 0.08),
          ),
          child: const Icon(Icons.cloud_off_rounded, size: 40, color: _C.rose),
        ),
        const SizedBox(height: 24),
        Text(msg,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _C.t2, fontSize: 14, height: 1.6)),
        const SizedBox(height: 32),
        _Btn(
            label: l.retry,
            icon: Icons.refresh_rounded,
            color: _C.blue,
            onTap: _load),
      ]),
    )));
  }

  // ══════════════════════════════════════════════════════════════════════════
  // MAIN BODY — completely new layout
  // ══════════════════════════════════════════════════════════════════════════
  Widget _body(Map<String, dynamic> trip) {
    final status = trip['status'] as String?;
    final driver = trip['driver'] as Map<String, dynamic>?;
    final canCancel = {'searching', 'accepted', 'in_progress'}.contains(status);
    final canTrack = {'accepted', 'in_progress'}.contains(status);
    final canComplain = {'completed', 'cancelled'}.contains(status);
    final canRate =
        status == 'completed' && trip['user_rating_to_driver'] == null;
    final rated =
        status == 'completed' && trip['user_rating_to_driver'] != null;

    final pLat = (trip['pickup_lat'] as num?)?.toDouble();
    final pLng = (trip['pickup_lng'] as num?)?.toDouble();
    final dLat = (trip['destination_lat'] as num?)?.toDouble();
    final dLng = (trip['destination_lng'] as num?)?.toDouble();

    final screenH = MediaQuery.of(context).size.height;
    final mapH = screenH * 0.44;

    return Stack(children: [
      // ── [1] Full-bleed map behind everything
      Positioned.fill(
        child: (pLat != null && pLng != null && pLat != 0.0 && pLng != 0.0)
          ? _buildMap(pLat, pLng, dLat, dLng, screenH - mapH)
          : Container(
              color: _C.card,
              child: const Center(
                  child: Icon(Icons.map_outlined, color: _C.t3, size: 64))),
      ),

      // ── [2] Header (Back, Status, Refresh)
      Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _MapCircleBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => context.pop()),
                Expanded(
                  child: Center(child: _statusPill(status)),
                ),
                _MapCircleBtn(icon: Icons.refresh_rounded, onTap: _load),
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
        child: (pLat != null && pLng != null) ? _MapCircleBtn(
          icon: Icons.my_location_rounded,
          onTap: () {
            if (_mapCtrl != null) {
              _mapCtrl!.animateCamera(CameraUpdate.newCameraPosition(
                CameraPosition(target: LatLng(pLat, pLng), zoom: 16),
              ));
            }
          },
        ) : const SizedBox.shrink(),
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
              decoration: const BoxDecoration(
                color: _C.sheet,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(children: [
                // handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _C.border, borderRadius: BorderRadius.circular(2)),
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
                            tripId: _trip?['id'] as String? ?? '',
                            canTrack: canTrack,
                            onTrack: () => context.push(
                                '${AppRoutes.userTracking}?tripId=${_trip!['id']}'),
                          ),
                          const SizedBox(height: 13),
                        ],

                        // Route ticket
                        _RouteTicket(trip: trip),
                        const SizedBox(height: 13),

                        // Price + stats (side by side, equal height)
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

                        // Horizontal timeline
                        _HTimeline(trip: trip),
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
              onCancel: () => _cancelDialog(trip['id'] as String),
              onRate: () =>
                  context.push('${AppRoutes.userRating}?tripId=${trip['id']}'),
              onComplain: () => _complaintDialog(trip['id'] as String),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Map ────────────────────────────────────────────────────────────────────
  Widget _buildMap(double pLat, double pLng, double? dLat, double? dLng, double bottomPadding) {
    final l = AppLocalizations.of(context)!;
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('p'),
        position: LatLng(pLat, pLng),
        icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: l.meetingPointLabel),
      ),
      if (dLat != null && dLng != null)
        Marker(
          markerId: const MarkerId('d'),
          position: LatLng(dLat, dLng),
          icon: _destIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: l.destination),
        ),
    };

    // Fetch route once
    if (dLat != null && dLng != null && !_routeFetchRequested) {
      _routeFetchRequested = true;
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _fetchRoute(pLat, pLng, dLat, dLng));
    }

    final polylines = <Polyline>{};
    if (_routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: _C.blue,
        width: 4,
      ));
    }

    return Stack(fit: StackFit.expand, children: [
      GoogleMap(
        initialCameraPosition:
            CameraPosition(target: LatLng(pLat, pLng), zoom: 15),
        style: kDarkMapStyle,
        minMaxZoomPreference: const MinMaxZoomPreference(10, 20),
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 60,
          bottom: bottomPadding + 20,
        ),
        onMapCreated: (ctrl) {
          _mapCtrl = ctrl;
          if (dLat != null && dLng != null && dLat != 0.0 && dLng != 0.0) {
            final pts = [LatLng(pLat, pLng), LatLng(dLat, dLng)];
            final sw = LatLng(
              pts.map((p) => p.latitude).reduce(math.min),
              pts.map((p) => p.longitude).reduce(math.min),
            );
            final ne = LatLng(
              pts.map((p) => p.latitude).reduce(math.max),
              pts.map((p) => p.longitude).reduce(math.max),
            );
            Future.delayed(
                const Duration(milliseconds: 500),
                () => _mapCtrl?.animateCamera(
                    CameraUpdate.newLatLngBounds(
                        LatLngBounds(southwest: sw, northeast: ne), 80)));
          } else {
            Future.delayed(const Duration(milliseconds: 400),
                () => _mapCtrl?.animateCamera(
                    CameraUpdate.newLatLngZoom(LatLng(pLat, pLng), 15)));
          }
        },
        markers: markers,
        polylines: polylines,
        zoomControlsEnabled: false,
        mapToolbarEnabled: false,
        myLocationButtonEnabled: false,
        compassEnabled: false,
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
            colors: [Colors.transparent, _C.bg.withValues(alpha: 0.88)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        )),
      ),
    ]);
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
          color: _C.sheet.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 22,
                spreadRadius: 2),
            const BoxShadow(color: Colors.black54, blurRadius: 10),
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
      builder: (dialogCtx) => _NightDialog(
        icon: Icons.warning_amber_rounded,
        iconColor: _C.rose,
        title: l.cancelTrip,
        body: l.areYouSureCancelTrip,
        confirmLabel: l.yesCancel,
        confirmColor: _C.rose,
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
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: _C.blue.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: const Icon(Icons.report_problem_rounded,
                      color: _C.blue, size: 20)),
              const SizedBox(width: 14),
              Text(l.submitComplaint,
                  style: const TextStyle(
                      color: _C.t1, fontSize: 17, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 20),
            Form(
                key: formKey,
                child: Column(children: [
                  _NightField(
                      ctrl: tCtrl,
                      label: l.complaintSubject,
                      hint: l.complaintSubjectHint,
                      icon: Icons.subject_rounded,
                      validator: (v) =>
                          v!.isEmpty ? l.complaintSubjectHint : null),
                  const SizedBox(height: 12),
                  _NightField(
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
                    style: const TextStyle(
                        color: _C.t2, fontWeight: FontWeight.w600)),
              ),
              const Spacer(),
              _Btn(
                  label: l.send,
                  icon: Icons.send_rounded,
                  color: _C.blue,
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

  // ── Helpers ────────────────────────────────────────────────────────────────
  Color _statusColor(String? s) => switch (s) {
        'completed' => _C.emerald,
        'cancelled' => _C.rose,
        'in_progress' || 'accepted' => _C.blue,
        'searching' => _C.amber,
        _ => _C.t2,
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

// ═══════════════════════════════════════════════════════════════════════════
//  SUB-WIDGETS
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
            color: _C.sheet.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            border: Border.all(color: _C.border, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
          ),
          child: Icon(icon, color: _C.t1, size: 18),
        ),
      );
}

// ── Driver strip (compact horizontal) ────────────────────────────────────────
class _DriverStrip extends StatelessWidget {
  final Map<String, dynamic> driver;
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
    final name = driver['name'] as String? ?? l.theDriver;
    final avatarUrl = driver['avatar_url'] as String?;
    final rating = driver['rating']?.toString() ?? '0.0';
    final plate = driver['vehicle_plate'] as String? ?? '';
    final driverId = driver['id'] as String?;
    final phone = driver['phone'] as String?;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Row(children: [
        // Avatar + online dot
        Stack(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_C.blue, Color(0xFF1F5EC4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 25,
              backgroundColor: _C.elevated,
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: const TextStyle(
                          color: _C.blue,
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
                  color: _C.emerald,
                  shape: BoxShape.circle,
                  border: Border.all(color: _C.card, width: 2),
                )),
          ),
        ]),
        const SizedBox(width: 12),

        // Name + meta
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(
                  color: _C.t1, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Row(children: [
            const Icon(Icons.star_rounded, color: _C.amber, size: 13),
            const SizedBox(width: 3),
            Text(rating,
                style: const TextStyle(
                    color: _C.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
            if (plate.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: _C.elevated,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _C.border),
                ),
                child: Text(plate,
                    style: const TextStyle(
                        color: _C.t2,
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
              color: _C.blue,
              onTap: () {
                if (tripId.isNotEmpty &&
                    driverId != null &&
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
                icon: Icons.phone_rounded, color: _C.emerald, onTap: () {}),
          ],
          if (canTrack) ...[
            const SizedBox(width: 8),
            _CircleAction(
                icon: Icons.my_location_rounded,
                color: _C.amber,
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
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Stack(children: [
        // notch left
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          child: Center(
              child: Container(
                  width: 5,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: _C.sheet,
                    borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8)),
                  ))),
        ),
        // notch right
        Positioned(
          right: 0,
          top: 0,
          bottom: 0,
          child: Center(
              child: Container(
                  width: 5,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: _C.sheet,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8)),
                  ))),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            // FROM
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
                          color: _C.emerald,
                          boxShadow: [
                            BoxShadow(
                                color: _C.emerald.withValues(alpha: 0.5),
                                blurRadius: 6)
                          ],
                        )),
                    const SizedBox(width: 7),
                    Text(l.meetingPointLabel.toUpperCase(),
                        style: const TextStyle(
                            color: _C.emerald,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                  ]),
                  const SizedBox(height: 8),
                  Text(pickup,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _C.t1,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.35)),
                ])),

            // divider
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
                          color: i.isEven ? _C.border : Colors.transparent,
                          shape: BoxShape.circle,
                        ))),
                const SizedBox(height: 4),
                const Icon(Icons.east_rounded, color: _C.t3, size: 14),
              ]),
            ),

            // TO
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Text(l.destination.toUpperCase(),
                        style: const TextStyle(
                            color: _C.blue,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5)),
                    const SizedBox(width: 7),
                    Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _C.blue,
                          boxShadow: [
                            BoxShadow(color: _C.blueGlow, blurRadius: 6)
                          ],
                        )),
                  ]),
                  const SizedBox(height: 8),
                  Text(dest,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                          color: _C.t1,
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

// ── Price Box ─────────────────────────────────────────────────────────────────
class _PriceBox extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _PriceBox({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final price = (trip['price'] as num?)?.toDouble() ?? 0;
    final discount = (trip['discount'] as num?)?.toDouble() ?? 0;
    final finalPrice = price - discount;
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
            style: const TextStyle(
                color: _C.t3,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8)),
        const SizedBox(height: 10),

        // hero number
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(finalPrice.toStringAsFixed(0),
                  style: const TextStyle(
                      color: _C.t1,
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 1)),
              const SizedBox(width: 5),
              Text(l.currencySar,
                  style: const TextStyle(
                      color: _C.t2, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),

        const Spacer(),

        // paid badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isPaid
                ? _C.emerald.withValues(alpha: 0.1)
                : _C.amber.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: isPaid
                    ? _C.emerald.withValues(alpha: 0.28)
                    : _C.amber.withValues(alpha: 0.28)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                    color: isPaid ? _C.emerald : _C.amber,
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(isPaid ? l.paid : l.unpaid,
                style: TextStyle(
                    color: isPaid ? _C.emerald : _C.amber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ]),
        ),

        if (discount > 0) ...[
          const SizedBox(height: 8),
          Text('- ${discount.toStringAsFixed(2)} ${l.currencySar}',
              style: const TextStyle(
                  color: _C.emerald,
                  fontSize: 11,
                  fontWeight: FontWeight.w600)),
        ],
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
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.tripDetails.toUpperCase(),
            style: const TextStyle(
                color: _C.t3,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.8)),
        const SizedBox(height: 14),
        _StatRow(
            icon: Icons.straighten_rounded,
            color: _C.blue,
            label: '$dist ${l.km}'),
        const SizedBox(height: 10),
        _StatRow(
            icon: Icons.directions_car_rounded, color: _C.violet, label: vName),
        const SizedBox(height: 10),
        _StatRow(
          icon: pay == 'cash'
              ? Icons.payments_rounded
              : Icons.credit_card_rounded,
          color: _C.amber,
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
                style: const TextStyle(
                    color: _C.t1, fontSize: 12, fontWeight: FontWeight.w600))),
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
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(l.timeline.toUpperCase(),
            style: const TextStyle(
                color: _C.t3,
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
              } catch (_) {}
            }

            return Expanded(
                child: Row(children: [
              Expanded(
                  child: Column(children: [
                // dot
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done ? _C.emerald : _C.elevated,
                    border:
                        done ? null : Border.all(color: _C.border, width: 1.5),
                    boxShadow: done
                        ? [
                            BoxShadow(
                                color: _C.emerald.withValues(alpha: 0.4),
                                blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: done
                      ? const Icon(Icons.check_rounded,
                          color: Colors.white, size: 11)
                      : null,
                ),
                const SizedBox(height: 7),
                Text(s.$1,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: done ? _C.t1 : _C.t3,
                      fontSize: 9.5,
                      fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                      height: 1.3,
                    )),
                if (t.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(t,
                      style: const TextStyle(
                          color: _C.emerald,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700)),
                ],
              ])),

              // connector
              if (!isLast)
                Expanded(
                    child: Container(
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

// ── Rating Badge ──────────────────────────────────────────────────────────────
class _RatingBadge extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _RatingBadge({required this.trip});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.emerald.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.emerald.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(children: [
        const Icon(Icons.verified_rounded, color: _C.emerald, size: 20),
        const SizedBox(width: 10),
        Expanded(
            child: Text(l.tripRated,
                style: const TextStyle(
                    color: _C.emerald,
                    fontSize: 13,
                    fontWeight: FontWeight.w700))),
        const Icon(Icons.star_rounded, color: _C.amber, size: 18),
        const SizedBox(width: 4),
        Text(trip['user_rating_to_driver'].toString(),
            style: const TextStyle(
                color: _C.t1, fontSize: 15, fontWeight: FontWeight.w800)),
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
        color: _C.sheet,
        border: const Border(top: BorderSide(color: _C.border, width: 1)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black45, blurRadius: 20, offset: Offset(0, -4))
        ],
      ),
      child: Row(children: [
        if (canCancel) ...[
          Expanded(
              child: _Btn(
                  label: l.cancelTrip,
                  icon: Icons.cancel_outlined,
                  color: _C.rose,
                  outlined: true,
                  onTap: onCancel)),
          if (canRate || canComplain) const SizedBox(width: 10),
        ],
        if (canRate) ...[
          Expanded(
              child: _Btn(
                  label: l.rateTrip,
                  icon: Icons.star_rounded,
                  color: _C.amber,
                  onTap: onRate)),
          if (canComplain) const SizedBox(width: 10),
        ],
        if (canComplain)
          Expanded(
              child: _Btn(
                  label: l.complaints,
                  icon: Icons.report_problem_outlined,
                  color: _C.blue,
                  outlined: true,
                  onTap: onComplain)),
      ]),
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
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 20)
              : null,
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
          child: Row(
            mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: outlined ? color : Colors.white, size: 17),
              const SizedBox(width: 7),
              Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: outlined ? color : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
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
        backgroundColor: _C.card,
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
                      style: const TextStyle(
                          color: _C.t1,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 14),
                Text(body,
                    style: const TextStyle(
                        color: _C.t2, fontSize: 14, height: 1.6)),
                const SizedBox(height: 24),
                Row(children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(cancelLabel,
                        style: const TextStyle(
                            color: _C.t2, fontWeight: FontWeight.w600)),
                  ),
                  const Spacer(),
                  _Btn(
                      label: confirmLabel,
                      icon: Icons.check_rounded,
                      color: confirmColor,
                      compact: true,
                      onTap: onConfirm),
                ]),
              ]),
        ),
      );
}

// ── Night text field ──────────────────────────────────────────────────────────
class _NightField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final int maxLines;
  final String? Function(String?)? validator;
  const _NightField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: ctrl,
        maxLines: maxLines,
        style: const TextStyle(color: _C.t1, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          labelStyle: const TextStyle(color: _C.t2),
          hintStyle: const TextStyle(color: _C.t3),
          prefixIcon: Icon(icon, color: _C.t2, size: 18),
          filled: true,
          fillColor: _C.elevated,
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.border)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.blue, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.rose, width: 1.5)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _C.rose, width: 1.5)),
        ),
        validator: validator,
      );
}