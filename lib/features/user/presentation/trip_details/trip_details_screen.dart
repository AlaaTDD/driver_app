
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/constants/map_styles.dart';
import '../trips/bloc/trips_bloc.dart';
import '../trips/bloc/trips_event.dart';
import '../trips/bloc/trips_state.dart';

class UserTripDetailsScreen extends StatefulWidget {
  final String tripId;

  const UserTripDetailsScreen({super.key, required this.tripId});

  @override
  State<UserTripDetailsScreen> createState() => _UserTripDetailsScreenState();
}

class _UserTripDetailsScreenState extends State<UserTripDetailsScreen> {
  GoogleMapController? _mapController;
  Map<String, dynamic>? _tripData;
  
  
  late final TripsBloc _tripsBloc;

  @override
  void initState() {
    super.initState();
    _tripsBloc = context.read<TripsBloc>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTripDetails();
    });
  }

  void _loadTripDetails() {
    _tripsBloc.add(LoadTripDetails(widget.tripId));
  }

  @override
  void dispose() {
    
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: context.bgColor,
      appBar: AppBar(
        backgroundColor: context.bgColor,
        title: Text(l.tripDetails),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadTripDetails,
            splashRadius: 24,
          ),
        ],
      ),
      body: BlocProvider.value(
        value: _tripsBloc,
        child: BlocConsumer<TripsBloc, TripsState>(
        listener: (context, state) {
          if (state is TripActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.success,
              ),
            );
            _loadTripDetails();
          } else if (state is TripsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is TripsLoading || state is TripDetailsLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (state is TripDetailsLoaded) {
            _tripData = state.trip;
            return _buildTripDetails(context, state.trip);
          }

          if (state is TripsError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: context.textDisabled),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: TextStyle(color: context.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadTripDetails,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                    ),
                    child: Text(l.retry),
                  ),
                ],
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
      ),
    );
  }

  Widget _buildTripDetails(BuildContext context, Map<String, dynamic> trip) {
    final driverData = trip['driver'] as Map<String, dynamic>?;
    final status = trip['status'] as String?;
    final canCancel = status == 'searching' || status == 'accepted' || status == 'in_progress';
    final canTrack = status == 'accepted' || status == 'in_progress';
    final canComplain = status == 'completed' || status == 'cancelled';
    final canRate = status == 'completed' && trip['user_rating_to_driver'] == null;

    final pickupLat = (trip['pickup_lat'] as num?)?.toDouble();
    final pickupLng = (trip['pickup_lng'] as num?)?.toDouble();
    final destLat = (trip['destination_lat'] as num?)?.toDouble();
    final destLng = (trip['destination_lng'] as num?)?.toDouble();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          if (pickupLat != null && pickupLng != null)
            _buildMapSection(pickupLat, pickupLng, destLat, destLng),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 16),
                
                _buildStatusHeader(context, trip, status),
                const SizedBox(height: 16),

                
                if (driverData != null) ...[
                  _buildDriverCard(context, driverData, canTrack),
                  const SizedBox(height: 16),
                ],

                
                _buildTripInfoCard(context, trip),
                const SizedBox(height: 16),

                
                _buildPriceCard(context, trip),
                const SizedBox(height: 16),

                
                _buildTimelineCard(context, trip),
                const SizedBox(height: 24),

                
                _buildActionButtons(context, trip, canCancel, canComplain, canRate),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection(double pickupLat, double pickupLng, double? destLat, double? destLng) {
    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('pickup'),
        position: LatLng(pickupLat, pickupLng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: InfoWindow(title: AppLocalizations.of(context)!.meetingPointLabel),
      ),
    };

    if (destLat != null && destLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(destLat, destLng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(title: AppLocalizations.of(context)!.destination),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
        child: GoogleMap(
          initialCameraPosition: CameraPosition(
            target: LatLng(pickupLat, pickupLng),
            zoom: 14,
          ),
          style: context.isDark ? kDarkMapStyle : kLightMapStyle,
          onMapCreated: (controller) {
            _mapController = controller;
          },
          markers: markers,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          myLocationButtonEnabled: false,
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, Map<String, dynamic> trip, String? status) {
    final l = AppLocalizations.of(context)!;
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.8), color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(_getStatusIcon(status), color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getStatusText(status, l),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getStatusDescription(status, l),
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverCard(BuildContext context, Map<String, dynamic> driver, bool canTrack) {
    final l = AppLocalizations.of(context)!;
    final avatarUrl = driver['avatar_url'] as String?;
    final vehiclePlate = driver['vehicle_plate'] as String? ?? '';
    final rating = driver['rating']?.toString() ?? '0.0';
    final phone = driver['phone'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.divColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.person_pin, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.theDriver,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                  child: avatarUrl == null
                      ? const Icon(Icons.person, color: AppColors.primary, size: 32)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driver['name'] ?? l.theDriver,
                        style: TextStyle(
                          color: context.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.star, color: AppColors.warning, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            rating,
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      if (vehiclePlate.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            vehiclePlate,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.message,
                    label: AppLocalizations.of(context)!.messages,
                    color: AppColors.primary,
                    onTap: () => context.push(AppRoutes.userMessages),
                  ),
                ),
                if (phone != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.phone,
                      label: AppLocalizations.of(context)!.call,
                      color: AppColors.success,
                      onTap: () {},
                    ),
                  ),
                ],
                if (canTrack) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.location_on,
                      label: AppLocalizations.of(context)!.track,
                      color: AppColors.primary,
                      onTap: () => context.push('${AppRoutes.userTracking}?tripId=${_tripData!['id']}'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTripInfoCard(BuildContext context, Map<String, dynamic> trip) {
    final l = AppLocalizations.of(context)!;
    final distance = (trip['distance_km'] as num?)?.toStringAsFixed(1) ?? '0';
    final vehicleType = trip['vehicle_type'] as String? ?? 'car';
    final paymentMethod = trip['payment_method'] as String? ?? 'cash';

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.divColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.tripDetails,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildLocationRow(
              icon: Icons.radio_button_on,
              iconColor: AppColors.success,
              title: l.meetingPointLabel,
              address: trip['meeting_address'] ?? trip['pickup_address'] ?? '',
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Divider(height: 1),
            ),
            _buildLocationRow(
              icon: Icons.location_on,
              iconColor: AppColors.primary,
              title: l.destination,
              address: trip['destination_address'] ?? '',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildInfoChip(
                  icon: Icons.straighten,
                  label: '$distance ${l.km}',
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  icon: Icons.local_taxi,
                  label: _getVehicleTypeName(vehicleType, AppLocalizations.of(context)!),
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  icon: Icons.payment,
                  label: paymentMethod == 'cash' ? l.cash : l.bankCard,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String address,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                address,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: context.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: context.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceCard(BuildContext context, Map<String, dynamic> trip) {
    final price = (trip['price'] as num?)?.toDouble() ?? 0;
    final discount = (trip['discount'] as num?)?.toDouble() ?? 0;
    final finalPrice = price - discount;
    final isPaid = trip['is_paid'] as bool? ?? false;

    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.divColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.fareDetails,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid ? AppColors.success.withValues(alpha: 0.1) : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    isPaid ? AppLocalizations.of(context)!.paid : AppLocalizations.of(context)!.unpaid,
                    style: TextStyle(
                      color: isPaid ? AppColors.success : AppColors.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildPriceRow(AppLocalizations.of(context)!.basePrice, price),
            if (discount > 0) ...[
              const SizedBox(height: 8),
              _buildPriceRow(AppLocalizations.of(context)!.discount, -discount, isDiscount: true),
            ],
            const Divider(height: 24),
            _buildPriceRow(AppLocalizations.of(context)!.total, finalPrice, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false, bool isDiscount = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isTotal ? context.textPrimary : context.textSecondary,
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '${amount.abs().toStringAsFixed(2)} ${AppLocalizations.of(context)!.currencySar}',
          style: TextStyle(
            color: isDiscount ? AppColors.success : (isTotal ? AppColors.primary : context.textPrimary),
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTimelineCard(BuildContext context, Map<String, dynamic> trip) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: context.divColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_toggle_off_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.timeline,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildTimelineItem(
              title: AppLocalizations.of(context)!.tripRequest,
              time: trip['created_at'],
              isFirst: true,
              isCompleted: true,
            ),
            _buildTimelineItem(
              title: AppLocalizations.of(context)!.acceptTrip,
              time: trip['accepted_at'],
              isCompleted: trip['accepted_at'] != null,
            ),
            _buildTimelineItem(
              title: AppLocalizations.of(context)!.startTrip,
              time: trip['started_at'],
              isCompleted: trip['started_at'] != null,
            ),
            _buildTimelineItem(
              title: AppLocalizations.of(context)!.completeTrip,
              time: trip['completed_at'],
              isLast: true,
              isCompleted: trip['completed_at'] != null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    dynamic time,
    bool isFirst = false,
    bool isLast = false,
    required bool isCompleted,
  }) {
    String timeText = '';
    if (time != null) {
      try {
        final dt = DateTime.parse(time.toString());
        timeText = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (e) { debugPrint('❌ Error: $e'); }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.success : context.textDisabled,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.bgColor, width: 2),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppColors.success.withValues(alpha: 0.3) : context.textDisabled,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isCompleted ? context.textPrimary : context.textDisabled,
                        fontSize: 14,
                        fontWeight: isCompleted ? FontWeight.w500 : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (timeText.isNotEmpty)
                    Text(
                      timeText,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    Map<String, dynamic> trip,
    bool canCancel,
    bool canComplain,
    bool canRate,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (canCancel)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _showCancelDialog(context, trip['id']),
                icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
                label: Text(
                  AppLocalizations.of(context)!.cancelTrip,
                  style: const TextStyle(color: AppColors.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (canRate) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => context.push('${AppRoutes.userRating}?tripId=${trip['id']}'),
                icon: const Icon(Icons.star, color: Colors.white),
                label: Text(AppLocalizations.of(context)!.rateTrip),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warning,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (canComplain) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _showComplaintDialog(context, trip['id']),
                icon: Icon(Icons.report_problem_outlined, color: AppColors.primary),
                label: Text(AppLocalizations.of(context)!.complaints),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
          if (trip['status'] == 'completed' && trip['user_rating_to_driver'] != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: AppColors.success),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.tripRated,
                      style: TextStyle(color: AppColors.success),
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.star, color: AppColors.warning, size: 18),
                      const SizedBox(width: 4),
                      Text(
                        trip['user_rating_to_driver'].toString(),
                        style: TextStyle(
                          color: context.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context, String tripId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.cancelTrip),
        content: Text(AppLocalizations.of(context)!.areYouSureCancelTrip),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(AppLocalizations.of(context)!.noLabel),
          ),
          ElevatedButton(
            onPressed: () {
              context.pop();
              _tripsBloc.add(CancelUserTrip(tripId));
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(AppLocalizations.of(context)!.yesCancel),
          ),
        ],
      ),
    );
  }

  void _showComplaintDialog(BuildContext context, String tripId) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.submitComplaint),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.complaintSubject,
                hintText: AppLocalizations.of(context)!.complaintSubjectHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.complaintDetails,
                hintText: AppLocalizations.of(context)!.complaintDetailsHint,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && descController.text.isNotEmpty) {
                context.pop();
                _tripsBloc.add(
                  SubmitTripComplaint(
                    tripId: tripId,
                    title: titleController.text,
                    description: descController.text,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: Text(AppLocalizations.of(context)!.send),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'cancelled':
        return AppColors.error;
      case 'in_progress':
      case 'accepted':
        return AppColors.primary;
      case 'searching':
        return AppColors.warning;
      default:
        return AppColors.textDisabled;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check;
      case 'cancelled':
        return Icons.cancel;
      case 'in_progress':
        return Icons.local_taxi;
      case 'accepted':
        return Icons.thumb_up;
      case 'searching':
        return Icons.search;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String? status, AppLocalizations l) {
    switch (status) {
      case 'completed':
        return l.completed;
      case 'cancelled':
        return l.cancelled;
      case 'in_progress':
        return l.inProgress;
      case 'accepted':
        return l.tripAccepted;
      case 'searching':
        return l.searchingForDriver;
      default:
        return status ?? l.pending;
    }
  }

  String _getStatusDescription(String? status, AppLocalizations l) {
    switch (status) {
      case 'completed':
        return l.tripCompleted;
      case 'cancelled':
        return l.cancelTrip;
      case 'in_progress':
        return l.inProgress;
      case 'accepted':
        return l.tripAccepted;
      case 'searching':
        return l.searchingForDriver;
      default:
        return l.pending;
    }
  }

  String _getVehicleTypeName(String type, AppLocalizations l) {
    switch (type) {
      case 'sedan':
        return l.sedan;
      case 'suv':
        return l.suv;
      case 'van':
        return l.van;
      case 'minibus':
        return l.minibus;
      case 'motorcycle':
        return l.motorcycle;
      default:
        return l.car;
    }
  }
}
