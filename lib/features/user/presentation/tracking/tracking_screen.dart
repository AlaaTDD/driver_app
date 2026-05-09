
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
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/constants/map_styles.dart';

class TripTrackingScreen extends StatefulWidget {
  final String tripId;
  const TripTrackingScreen({super.key, required this.tripId});

  @override
  State<TripTrackingScreen> createState() => _TripTrackingScreenState();
}

class _TripTrackingScreenState extends State<TripTrackingScreen> {
  GoogleMapController? _mapController;
  BitmapDescriptor? _carIcon;
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _destIcon;

  // ─── Smooth interpolation (no AnimationController, no setState) ───────────
  final ValueNotifier<Marker?> _driverMarkerNotifier = ValueNotifier(null);
  LatLng? _targetDriverPosition;
  LatLng? _animatedDriverPosition;
  double _driverRotation = 0.0;
  Timer? _animationTimer;

  static const _defaultCamera = CameraPosition(
    target: AppConstants.defaultMapCenter,
    zoom: 14,
  );

  @override
  void initState() {
    super.initState();
    _loadCarIcon();
    _loadCircleIcons();
    _startAnimationLoop();
    context.read<TrackingBloc>().add(LoadTripTracking(widget.tripId));
  }

  Future<void> _loadCircleIcons() async {
    _pickupIcon = await _createCircleMarker(Colors.green);
    _destIcon = await _createCircleMarker(Colors.red);
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
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(20, 20), 5, whitePaint);
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(40, 40);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(bytes!.buffer.asUint8List());
  }

  void _startAnimationLoop() {
    _animationTimer = Timer.periodic(const Duration(milliseconds: 32), (_) {
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
  }

  Future<void> _loadCarIcon() async {
    try {
      final data = await rootBundle.load('assets/images/carr.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 40);
      final frame = await codec.getNextFrame();
      final resizedBytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);
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
    _animationTimer?.cancel();
    _driverMarkerNotifier.dispose();
    _mapController?.dispose();
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
      icon: _carIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
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
        
        final targetLat = (state.trip[isHeadingToDest ? 'destination_lat' : 'pickup_lat'] as num?)?.toDouble();
        final targetLng = (state.trip[isHeadingToDest ? 'destination_lng' : 'pickup_lng'] as num?)?.toDouble();
        
        if (targetLat != null && targetLng != null && targetLat != 0.0 && targetLng != 0.0) {
          final bounds = LatLngBounds(
            southwest: LatLng(math.min(lat, targetLat), math.min(lng, targetLng)),
            northeast: LatLng(math.max(lat, targetLat), math.max(lng, targetLng)),
          );
          // Add padding (e.g. 80) to ensure markers are well within view
          await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
          return;
        }
      }

      // Fallback: just center on driver if target is unknown
      await _mapController!.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
    } catch (e) {
      debugPrint('⚠️ TrackingScreen: animateCamera failed: $e');
    }
  }

  // ── color tokens (matches trip_details) ─────────────────────────────────
  static const _bg      = Color(0xFF0D0F18);
  static const _sheet   = Color(0xFF12151F);
  static const _card    = Color(0xFF181C2A);
  static const _elevated= Color(0xFF1E2336);
  static const _border  = Color(0xFF252A3D);
  static const _blue    = Color(0xFF4C8BF5);
  static const _emerald = Color(0xFF1FC87A);
  static const _rose    = Color(0xFFFF4060);
  static const _amber   = Color(0xFFF5A524);
  static const _t1      = Color(0xFFEEF0FF);
  static const _t2      = Color(0xFF7B82A3);
  static const _t3      = Color(0xFF3A4060);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: BlocListener<TrackingBloc, TrackingState>(
        listener: (context, state) {
          if (state is TrackingLoaded) {
            final loc = state.driverLocation;
            if (loc != null) {
              _animateTo(loc.latitude, loc.longitude);
              _updateDriverPosition(LatLng(loc.latitude, loc.longitude));
            }
            if (state.trip['status'] == 'completed') {
              context.go('${AppRoutes.userRating}?tripId=${state.trip['id']}');
            } else if (state.trip['status'] == 'cancelled') {
              context.go(AppRoutes.userHome);
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
      Container(height: h * 0.55, color: _card),
      Expanded(child: Container(color: _sheet, padding: const EdgeInsets.all(20),
        child: Column(children: [
          const SizedBox(height: 8),
          Container(height: 28, width: 160, decoration: BoxDecoration(color: _elevated, borderRadius: BorderRadius.circular(14))),
          const SizedBox(height: 20),
          Container(height: 80, decoration: BoxDecoration(color: _elevated, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 12),
          Container(height: 80, decoration: BoxDecoration(color: _elevated, borderRadius: BorderRadius.circular(16))),
        ]),
      )),
    ]);
  }

  Widget _buildError(BuildContext context, String message) {
    return SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 88, height: 88,
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: _rose.withValues(alpha: 0.3)),
            color: _rose.withValues(alpha: 0.08)),
          child: const Icon(Icons.cloud_off_rounded, size: 40, color: _rose)),
        const SizedBox(height: 24),
        Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: _t2, fontSize: 14, height: 1.6)),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: () => context.read<TrackingBloc>().add(LoadTripTracking(widget.tripId)),
          child: Container(height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_blue, Color(0xFF1F5EC4)]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))]),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.refresh_rounded, color: Colors.white, size: 17),
              SizedBox(width: 7),
              Text('Retry', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            ])),
        ),
      ]),
    )));
  }


  Widget _buildTracking(BuildContext context, TrackingLoaded state) {
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
        position: LatLng((pickupLat as num).toDouble(), (pickupLng as num).toDouble()),
        icon: _pickupIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        anchor: const Offset(0.5, 0.5),
        zIndex: 1,
        infoWindow: InfoWindow(title: AppLocalizations.of(context)!.meetingPointLabel),
      ));
    }
    if (destLat != null && destLng != null) {
      staticMarkers.add(Marker(
        markerId: const MarkerId('destination'),
        position: LatLng((destLat as num).toDouble(), (destLng as num).toDouble()),
        icon: _destIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 0.5),
        zIndex: 1,
        infoWindow: InfoWindow(title: AppLocalizations.of(context)!.destination),
      ));
    }
    if (state.routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: state.routePoints,
        color: _blue,
        width: 5,
      ));
    }

    final screenH = MediaQuery.of(context).size.height;
    final mapH = screenH * 0.55;
    final tripStatus = state.trip['status'] as String?;
    final l = AppLocalizations.of(context)!;

    return Stack(children: [
      // Full-bleed map
      Positioned.fill(
        child: ValueListenableBuilder<Marker?>(
          valueListenable: _driverMarkerNotifier,
          builder: (context, driverMarker, _) {
            final allMarkers = Set<Marker>.from(staticMarkers);
            if (driverMarker != null) allMarkers.add(driverMarker);
            return Stack(fit: StackFit.expand, children: [
              GoogleMap(
                initialCameraPosition: _defaultCamera,
                onMapCreated: (ctrl) { _mapController = ctrl; _fitBounds(ctrl, state); },
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
              ),
              Positioned(bottom: 0, left: 0, right: 0, height: 80,
                child: DecoratedBox(decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, _bg.withValues(alpha: 0.88)],
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  ),
                ))),
            ]);
          },
        ),
      ),

      // Header
      Positioned(
        top: 0, left: 0, right: 0,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _MapBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () { if (context.canPop()) context.pop(); else context.go(AppRoutes.userHome); },
                ),
                Expanded(
                  child: Center(child: _statusPill(tripStatus, l)),
                ),
                const SizedBox(width: 42), // Balance the row
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
        top: mapH - 12, left: 0, right: 0, bottom: 0,
        child: Container(
          decoration: const BoxDecoration(
            color: _sheet,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              width: 36, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (state.driver != null) ...[
                  _buildDriverCard(context, state.driver!, state),
                  const SizedBox(height: 12),
                ],
                _buildRouteCard(context, state.trip, l),
                const SizedBox(height: 12),
                if (tripStatus != 'completed' && tripStatus != 'cancelled')
                  GestureDetector(
                    onTap: () => context.read<TrackingBloc>().add(CancelTrip(widget.tripId)),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _rose.withValues(alpha: 0.5), width: 1.2),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.cancel_outlined, color: _rose, size: 17),
                        const SizedBox(width: 7),
                        Text(l.cancelTrip, style: const TextStyle(color: _rose, fontSize: 13, fontWeight: FontWeight.w700)),
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

  Widget _statusPill(String? status, AppLocalizations l) {
    final color = switch (status) {
      'completed' => _emerald, 'cancelled' => _rose,
      'in_progress' || 'accepted' => _blue, 'searching' => _amber, _ => _t2,
    };
    final label = switch (status) {
      'completed' => l.completed, 'cancelled' => l.cancelled,
      'in_progress' => l.inProgress, 'accepted' => l.tripAccepted,
      'searching' => l.searchingForDriver, _ => l.pending,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _sheet.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 20),
          const BoxShadow(color: Colors.black54, blurRadius: 10),
        ],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)])),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
      ]),
    );
  }

  Widget _buildRouteCard(BuildContext context, Map<String, dynamic> trip, AppLocalizations l) {
    final pickup = trip['meeting_address'] ?? trip['pickup_address'] ?? '';
    final dest = trip['destination_address'] ?? '';
    final price = trip['price'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(
            shape: BoxShape.circle, color: _emerald,
            boxShadow: [BoxShadow(color: _emerald.withValues(alpha: 0.5), blurRadius: 6)])),
          const SizedBox(width: 8),
          Expanded(child: Text(pickup.isEmpty ? '---' : pickup,
            style: const TextStyle(color: _t1, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        Padding(padding: const EdgeInsets.fromLTRB(4, 6, 0, 6),
          child: Container(width: 1, height: 18, color: _border)),
        Row(children: [
          Container(width: 9, height: 9, decoration: BoxDecoration(
            shape: BoxShape.circle, color: _blue,
            boxShadow: [BoxShadow(color: _blue.withValues(alpha: 0.4), blurRadius: 6)])),
          const SizedBox(width: 8),
          Expanded(child: Text(dest.isEmpty ? '---' : dest,
            style: const TextStyle(color: _t1, fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
        ]),
        if (price != null) ...[
          const SizedBox(height: 12),
          Container(height: 1, color: _border),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.payments_rounded, color: _amber, size: 16),
            const SizedBox(width: 8),
            Text('$price ${l.currencySar}',
              style: const TextStyle(color: _t1, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
        ],
      ]),
    );
  }

  Widget _buildDriverCard(BuildContext context, Map<String, dynamic> driver, TrackingLoaded state) {
    final avatarUrl = driver['avatar_url'] as String?;
    final tripId = state.trip['id'] as String?;
    final name = driver['name'] as String? ?? AppLocalizations.of(context)!.theDriver;
    final rating = driver['rating']?.toString() ?? '0.0';
    final plate = driver['vehicle_plate'] as String? ?? '';
    final driverId = driver['id'] as String?;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 1),
      ),
      child: Row(children: [
        // Avatar
        Stack(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [_blue, Color(0xFF1F5EC4)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: _elevated,
              backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'D',
                      style: const TextStyle(color: _blue, fontSize: 17, fontWeight: FontWeight.w800))
                  : null,
            ),
          ),
          Positioned(bottom: 1, right: 1,
            child: Container(width: 11, height: 11,
              decoration: BoxDecoration(
                color: _emerald, shape: BoxShape.circle,
                border: Border.all(color: _card, width: 2)))),
        ]),
        const SizedBox(width: 12),
        // Name + meta
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(color: _t1, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(children: [
            const Icon(Icons.star_rounded, color: _amber, size: 13),
            const SizedBox(width: 3),
            Text(rating, style: const TextStyle(color: _amber, fontSize: 11, fontWeight: FontWeight.w700)),
            if (plate.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _elevated, borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _border)),
                child: Text(plate, style: const TextStyle(
                  color: _t2, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              ),
            ],
          ]),
        ])),
        // Chat button
        GestureDetector(
          onTap: () {
            if (tripId != null && tripId.isNotEmpty && driverId != null) {
              context.push('${AppRoutes.userMessages}?tripId=$tripId&otherUserId=$driverId&otherUserName=${Uri.encodeComponent(name)}');
            } else {
              context.push(AppRoutes.userMessages);
            }
          },
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _blue.withValues(alpha: 0.1), shape: BoxShape.circle,
              border: Border.all(color: _blue.withValues(alpha: 0.25), width: 1)),
            child: const Icon(Icons.chat_bubble_rounded, color: _blue, size: 16)),
        ),
      ]),
    );
  }

  void _fitBounds(GoogleMapController ctrl, TrackingLoaded state) {
    final points = <LatLng>[];
    if (state.driverLocation != null && state.driverLocation!.latitude != 0.0 && state.driverLocation!.longitude != 0.0) {
      points.add(LatLng(state.driverLocation!.latitude, state.driverLocation!.longitude));
    }
    if (state.trip['pickup_lat'] != null && state.trip['pickup_lng'] != null && state.trip['pickup_lat'] != 0.0 && state.trip['pickup_lng'] != 0.0) {
      points.add(LatLng(
        (state.trip['pickup_lat'] as num).toDouble(),
        (state.trip['pickup_lng'] as num).toDouble(),
      ));
    }
    if (state.trip['destination_lat'] != null && state.trip['destination_lng'] != null && state.trip['destination_lat'] != 0.0 && state.trip['destination_lng'] != 0.0) {
      points.add(LatLng(
        (state.trip['destination_lat'] as num).toDouble(),
        (state.trip['destination_lng'] as num).toDouble(),
      ));
    }
    if (state.routePoints.isNotEmpty) points.addAll(state.routePoints.where((p) => p.latitude != 0.0 && p.longitude != 0.0));
    
    if (points.isEmpty) return;
    
    // Single point → zoom to it directly
    if (points.length == 1) {
      Future.delayed(const Duration(milliseconds: 400), () {
        ctrl.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
      });
      return;
    }

    final sw = LatLng(
      points.map((p) => p.latitude).reduce(math.min),
      points.map((p) => p.longitude).reduce(math.min),
    );
    final ne = LatLng(
      points.map((p) => p.latitude).reduce(math.max),
      points.map((p) => p.longitude).reduce(math.max),
    );
    Future.delayed(const Duration(milliseconds: 400), () {
      ctrl.animateCamera(CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: sw, northeast: ne), 80));
    });
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
      width: 42, height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF12151F).withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF252A3D), width: 1),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 10)],
      ),
      child: Icon(icon, color: const Color(0xFFEEF0FF), size: 18),
    ),
  );
}
