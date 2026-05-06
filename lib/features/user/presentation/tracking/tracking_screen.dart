
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
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/error/error_mapper.dart';
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
    
    // Draw outer circle with opacity
    final outerPaint = Paint()..color = color.withOpacity(0.3);
    canvas.drawCircle(const Offset(30, 30), 30, outerPaint);
    
    // Draw solid inner circle
    canvas.drawCircle(const Offset(30, 30), 12, paint);
    
    // Draw tiny white center
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawCircle(const Offset(30, 30), 6, whitePaint);
    
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(60, 60);
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
      _mapController?.animateCamera(CameraUpdate.newLatLng(LatLng(lat, lng)));
    } catch (e) {
      debugPrint('⚠️ TrackingScreen: animateCamera failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<TrackingBloc, TrackingState>(
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
        backgroundColor: context.bgColor,
        appBar: AppBar(
          backgroundColor: context.bgColor,
          title: Text(AppLocalizations.of(context)!.trackTrip),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) context.pop();
              else context.go(AppRoutes.userHome);
            },
          ),
        ),
        body: Builder(
          builder: (context) {
            final state = context.watch<TrackingBloc>().state;
            if (state is TrackingLoading || state is TrackingInitial) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (state is TrackingError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(ErrorMapper.getErrorMessage(context, state.message),
                        style: TextStyle(color: context.textPrimary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.read<TrackingBloc>().add(
                          LoadTripTracking(widget.tripId)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                      child: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ],
                ),
              );
            }
            if (state is TrackingLoaded) return _buildTracking(context, state);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildTracking(BuildContext context, TrackingLoaded state) {
    // If we already have a driver location (from initial DB fetch), ensure the marker is set
    if (state.driverLocation != null && _targetDriverPosition == null) {
      final loc = state.driverLocation!;
      // Schedule this after build to avoid setState-during-build issues
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _updateDriverPosition(LatLng(loc.latitude, loc.longitude));
        _animateTo(loc.latitude, loc.longitude);
      });
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
        color: AppColors.primary,
        width: 5,
      ));
    }

    return Column(
      children: [
        Expanded(
          // ValueListenableBuilder يُعيد بناء الـ Marker فقط بدون setState
          child: ValueListenableBuilder<Marker?>(
            valueListenable: _driverMarkerNotifier,
            builder: (context, driverMarker, child) {
              final allMarkers = Set<Marker>.from(staticMarkers);
              if (driverMarker != null) allMarkers.add(driverMarker);
              return GoogleMap(
                initialCameraPosition: _defaultCamera,
                onMapCreated: (ctrl) {
                  _mapController = ctrl;
                  _fitBounds(ctrl, state);
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                markers: allMarkers,
                polylines: polylines,
                style: context.isDark ? kDarkMapStyle : kLightMapStyle,
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          color: context.cardColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.driver != null) _buildDriverCard(context, state.driver!, state),
              const SizedBox(height: 12),
              _buildTripDetails(context, state.trip),
              const SizedBox(height: 12),
              if (state.trip['status'] != 'completed')
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => context.read<TrackingBloc>().add(CancelTrip(widget.tripId)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(AppLocalizations.of(context)!.cancelTrip),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDriverCard(BuildContext context, Map<String, dynamic> driver, TrackingLoaded state) {
    final avatarUrl = driver['avatar_url'] as String?;
    final tripId = state.trip['id'] as String?;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: context.primaryTint,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person_rounded, color: AppColors.primary, size: 28)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  driver['name'] as String? ?? AppLocalizations.of(context)!.theDriver,
                  style: TextStyle(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.warning, size: 14),
                    const SizedBox(width: 4),
                    Text(driver['rating']?.toString() ?? '0.0',
                        style: TextStyle(color: context.textSecondary, fontSize: 13)),
                    const SizedBox(width: 12),
                    Text(driver['vehicle_plate'] as String? ?? '',
                        style: TextStyle(color: context.textSecondary, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.message_rounded, color: AppColors.primary),
            onPressed: () {
              if (tripId != null && tripId.isNotEmpty) {
                context.push('${AppRoutes.userMessages}?tripId=$tripId');
              } else {
                context.push(AppRoutes.userMessages);
              }
            },
          ),
        ],
      ),
    );
  }

  void _fitBounds(GoogleMapController ctrl, TrackingLoaded state) {
    final points = <LatLng>[];
    if (state.driverLocation != null) {
      points.add(LatLng(state.driverLocation!.latitude, state.driverLocation!.longitude));
    }
    if (state.trip['pickup_lat'] != null) {
      points.add(LatLng(
        (state.trip['pickup_lat'] as num).toDouble(),
        (state.trip['pickup_lng'] as num).toDouble(),
      ));
    }
    if (state.trip['destination_lat'] != null) {
      points.add(LatLng(
        (state.trip['destination_lat'] as num).toDouble(),
        (state.trip['destination_lng'] as num).toDouble(),
      ));
    }
    if (state.routePoints.isNotEmpty) points.addAll(state.routePoints);
    if (points.length >= 2) {
      final sw = LatLng(
        points.map((p) => p.latitude).reduce(math.min),
        points.map((p) => p.longitude).reduce(math.min),
      );
      final ne = LatLng(
        points.map((p) => p.latitude).reduce(math.max),
        points.map((p) => p.longitude).reduce(math.max),
      );
      Future.delayed(const Duration(milliseconds: 400), () {
        ctrl.animateCamera(CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 80));
      });
    }
  }

  Widget _buildTripDetails(BuildContext context, Map<String, dynamic> trip) {
    return Column(
      children: [
        _DetailRow(
          icon: Icons.radio_button_on,
          iconColor: AppColors.success,
          label: AppLocalizations.of(context)!.meetingPointLabel,
          value: trip['meeting_address'] as String? ?? '',
        ),
        const SizedBox(height: 6),
        _DetailRow(
          icon: Icons.location_on_rounded,
          iconColor: AppColors.primary,
          label: AppLocalizations.of(context)!.destination,
          value: trip['destination_address'] as String? ?? '',
        ),
        const SizedBox(height: 6),
        _DetailRow(
          icon: Icons.payments_rounded,
          iconColor: AppColors.warning,
          label: AppLocalizations.of(context)!.price,
          value: '${trip['price'] ?? 0} ${AppLocalizations.of(context)!.currencySar}',
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 16),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: context.textSecondary, fontSize: 13)),
        Expanded(
          child: Text(value,
              style: TextStyle(color: context.textPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
