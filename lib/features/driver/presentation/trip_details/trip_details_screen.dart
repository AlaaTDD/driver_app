// lib/features/driver/presentation/trip_details/trip_details_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bloc/trip_details_bloc.dart';
import 'bloc/trip_details_event.dart';
import 'bloc/trip_details_state.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/map_styles.dart';
import '../../../../services/directions_service.dart';
import '../../../../core/constants/env_constants.dart';

class DriverTripDetailsScreen extends StatefulWidget {
  final String tripId;

  const DriverTripDetailsScreen({super.key, required this.tripId});

  @override
  State<DriverTripDetailsScreen> createState() => _DriverTripDetailsScreenState();
}

class _DriverTripDetailsScreenState extends State<DriverTripDetailsScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  List<LatLng> _routePoints = [];
  bool _routeFetchRequested = false;

  @override
  void initState() {
    super.initState();
    context.read<TripDetailsBloc>().add(LoadTripDetails(widget.tripId));
  }

  Future<void> _fetchRoute(double originLat, double originLng, double destLat, double destLng) async {
    final result = await DirectionsService.getRoute(
      originLat: originLat, originLng: originLng,
      destLat: destLat, destLng: destLng,
      apiKey: EnvConstants.googleMapsApiKey,
    );
    if (!mounted || result == null) return;
    setState(() => _routePoints = result.points);
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TripDetailsBloc, TripDetailsState>(
      listener: (context, state) {
        if (state is TripDetailsLoaded) {
          final status = state.trip['status'] as String?;
          if (status == 'completed') {
            AppToast.success(AppLocalizations.of(context)!.tripCompleted);
            context.go('${AppRoutes.driverRating}?tripId=${widget.tripId}');
          }
          final pickup = state.trip['pickup_lat'];
          if (pickup != null) {
            _mapController.future.then((ctrl) => ctrl.animateCamera(
                  CameraUpdate.newLatLng(LatLng(
                    (state.trip['pickup_lat'] as num).toDouble(),
                    (state.trip['pickup_lng'] as num).toDouble(),
                  )),
                ));
          }
        } else if (state is TripDetailsError) {
          AppToast.error(ErrorMapper.getErrorMessage(context, state.message));
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: context.bgColor,
          appBar: AppBar(
            backgroundColor: context.bgColor,
            title: Text(AppLocalizations.of(context)!.tripDetails),
          ),
          body: () {
            if (state is TripDetailsLoading || state is TripDetailsInitial) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (state is TripDetailsError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(state.message,
                        style: TextStyle(color: context.textPrimary)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context
                          .read<TripDetailsBloc>()
                          .add(LoadTripDetails(widget.tripId)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      child: Text(AppLocalizations.of(context)!.retry),
                    ),
                  ],
                ),
              );
            }
            if (state is TripDetailsLoaded) {
              return _buildBody(context, state.trip);
            }
            return const SizedBox.shrink();
          }(),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic> trip) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    if (trip['pickup_lat'] != null) {
      markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(
          (trip['pickup_lat'] as num).toDouble(),
          (trip['pickup_lng'] as num).toDouble(),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: trip['pickup_address'] as String? ?? AppLocalizations.of(context)!.meetingPointLabel),
      ));
    }
    if (trip['destination_lat'] != null) {
      markers.add(Marker(
        markerId: const MarkerId('dest'),
        position: LatLng(
          (trip['destination_lat'] as num).toDouble(),
          (trip['destination_lng'] as num).toDouble(),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: InfoWindow(title: trip['destination_address'] as String? ?? AppLocalizations.of(context)!.destination),
      ));
    }

    // FIX M12: Never call async network functions inside build.
    // Defer route fetch to after frame with a guard flag.
    final pickupLat = trip['pickup_lat'] as num?;
    final pickupLng = trip['pickup_lng'] as num?;
    final destLat = trip['destination_lat'] as num?;
    final destLng = trip['destination_lng'] as num?;
    if (pickupLat != null && pickupLng != null && destLat != null && destLng != null && !_routeFetchRequested) {
      _routeFetchRequested = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fetchRoute(pickupLat.toDouble(), pickupLng.toDouble(), destLat.toDouble(), destLng.toDouble());
      });
    }

    if (_routePoints.isNotEmpty) {
      polylines.add(Polyline(
        polylineId: const PolylineId('route'),
        points: _routePoints,
        color: AppColors.primary,
        width: 5,
      ));
    }

    final initTarget = trip['pickup_lat'] != null
        ? LatLng((trip['pickup_lat'] as num).toDouble(),
            (trip['pickup_lng'] as num).toDouble())
        : AppConstants.defaultMapCenter;

    return Column(
      children: [
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: initTarget, zoom: 14),
            onMapCreated: (ctrl) {
              if (!_mapController.isCompleted) {
                _mapController.complete(ctrl);
              }
              _fitMapBounds(ctrl, markers);
            },
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: markers,
            polylines: polylines,
            style: context.isDark ? kDarkMapStyle : kLightMapStyle,
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          color: context.cardColor,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUserCard(trip['user'] as Map?),
              const SizedBox(height: 12),
              _buildTripInfo(trip),
              const SizedBox(height: 12),
              _buildActionButtons(context, trip),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map? user) {
    if (user == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: context.primaryTint,
            child: const Icon(Icons.person_rounded,
                color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'] as String? ?? AppLocalizations.of(context)!.userDefault,
                    style: TextStyle(
                        color: context.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Row(children: [
                  const Icon(Icons.star_rounded,
                      color: AppColors.warning, size: 14),
                  const SizedBox(width: 4),
                  Text(user['rating']?.toString() ?? '0.0',
                      style: TextStyle(
                          color: context.textSecondary, fontSize: 13)),
                ]),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.message_rounded, color: AppColors.primary),
            onPressed: () => context.push('${AppRoutes.driverMessages}?tripId=${widget.tripId}'),
          ),
        ],
      ),
    );
  }

  Widget _buildTripInfo(Map<String, dynamic> trip) {
    return Column(
      children: [
        _InfoRow(icon: Icons.radio_button_on, iconColor: AppColors.success,
            label: AppLocalizations.of(context)!.meetingPointLabel,
            value: trip['meeting_address'] as String? ?? trip['pickup_address'] as String? ?? ''),
        const SizedBox(height: 6),
        _InfoRow(icon: Icons.location_on_rounded, iconColor: AppColors.primary,
            label: AppLocalizations.of(context)!.destination,
            value: trip['destination_address'] as String? ?? ''),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _InfoRow(icon: Icons.payments_rounded, iconColor: AppColors.warning,
                label: AppLocalizations.of(context)!.price, value: '${trip['price'] ?? 0} ${AppLocalizations.of(context)!.currencySar}'),
            _InfoRow(icon: Icons.route_rounded, iconColor: context.textSecondary,
                label: AppLocalizations.of(context)!.distance,
                value: '${(trip['distance_km'] as num?)?.toStringAsFixed(1) ?? '0'} ${AppLocalizations.of(context)!.km}'),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, Map<String, dynamic> trip) {
    final status = trip['status'] as String?;
    final btnStyle = ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    if (status == 'searching' || status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () => context.read<TripDetailsBloc>().add(AcceptTrip(widget.tripId)),
              style: btnStyle,
              child: Text(AppLocalizations.of(context)!.acceptTrip),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton(
              onPressed: () => context.read<TripDetailsBloc>().add(RejectTrip(widget.tripId)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(AppLocalizations.of(context)!.reject),
            ),
          ),
        ],
      );
    } else if (status == 'accepted') {
      return ElevatedButton(
        onPressed: () => context.read<TripDetailsBloc>().add(StartTrip(widget.tripId)),
        style: btnStyle,
        child: Text(AppLocalizations.of(context)!.startTrip),
      );
    } else if (status == 'in_progress') {
      return ElevatedButton(
        onPressed: () => context.read<TripDetailsBloc>().add(CompleteTrip(widget.tripId)),
        style: btnStyle.copyWith(
          backgroundColor: WidgetStatePropertyAll(AppColors.success),
        ),
        child: Text(AppLocalizations.of(context)!.completeTrip),
      );
    }
    return const SizedBox.shrink();
  }

  void _fitMapBounds(GoogleMapController ctrl, Set<Marker> markers) {
    if (markers.length < 2) return;
    final points = markers.map((m) => m.position).toList();
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
        LatLngBounds(southwest: sw, northeast: ne),
        80,
      ));
    });
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: iconColor, size: 15),
        const SizedBox(width: 6),
        Text('$label: ',
            style: TextStyle(
                color: context.textSecondary, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: context.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}


