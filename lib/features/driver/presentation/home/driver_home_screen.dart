// lib/features/driver/presentation/home/driver_home_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bloc/driver_home_bloc.dart';
import 'bloc/driver_home_event.dart';
import 'bloc/driver_home_state.dart';
import '../../../../core/constants/map_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/bottom_sheet_container.dart';
import '../../../../core/widgets/map_button.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/heatmap_service.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with WidgetsBindingObserver {
  // ─── Map Controller ────────────────────────────────────────────────────────
  // Use a nullable controller instead of Completer to safely handle
  // re-creation when the user navigates away and back.
  GoogleMapController? _mapController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _defaultCamera = CameraPosition(
    target: AppConstants.defaultMapCenter,
    zoom: 15,
  );

  // Track last animated position to avoid redundant camera moves
  double? _lastAnimatedLat;
  double? _lastAnimatedLng;

  // Track if we already initialized to avoid re-init on re-entry
  bool _initialized = false;

  // ─── Layout Constants ────────────────────────────────────────────────────
  static const double _bottomSheetHeight = 236.0;
  static const double _mapButtonSize = 48.0;
  static const double _mapButtonRadius = 14.0;
  static const double _topBarHorizontalPadding = 18.0;
  static const double _topBarVerticalPadding = 14.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only load once — not on every hot-reload or navigation back
    if (!_initialized) {
      _initialized = true;
      context.read<DriverHomeBloc>().add(LoadDriverStatus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose the controller safely to prevent memory leaks
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // When app comes back to foreground, refresh location once
    if (state == AppLifecycleState.resumed) {
      final bloc = context.read<DriverHomeBloc>();
      if (bloc.state.isAvailable) {
        bloc.add(RefreshDriverLocation());
      }
    }
  }

  // ─── Camera Control ───────────────────────────────────────────────────────

  /// Move camera to position — only if position actually changed
  Future<void> _animateTo(double lat, double lng) async {
    if (_mapController == null) return;
    // Skip if already at this position (prevents jump on re-entry)
    if (_lastAnimatedLat == lat && _lastAnimatedLng == lng) return;
    _lastAnimatedLat = lat;
    _lastAnimatedLng = lng;
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 15),
        ),
      );
    } catch (e) {
      debugPrint('⚠️ DriverHome: animateCamera failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DriverHomeBloc, DriverHomeState>(
      listenWhen: (prev, curr) =>
          (prev.driverLat != curr.driverLat ||
              prev.driverLng != curr.driverLng) &&
          curr.driverLat != null &&
          curr.driverLng != null,
      listener: (context, state) {
        if (state.driverLat != null && state.driverLng != null) {
          _animateTo(state.driverLat!, state.driverLng!);
        }
      },
      child: BlocListener<DriverHomeBloc, DriverHomeState>(
        // FIX P1-03: Navigate to trip details when a trip is accepted
        listenWhen: (prev, curr) =>
            prev.acceptedTripId != curr.acceptedTripId &&
            curr.acceptedTripId != null,
        listener: (context, state) {
          if (state.acceptedTripId != null) {
            context.push(
              '${AppRoutes.driverTripDetails}?tripId=${state.acceptedTripId}',
            );
          }
        },
        child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: context.bgColor,
        drawer: _buildDrawer(context),
        body: Stack(
          children: [
            _buildMap(),
            _buildTopBar(),
            _buildLocationButton(),
            _buildBottomPanel(),
          ],
        ),
      ),
    ),
  );
  }

  // ─── Map with Heatmap overlay ─────────────────────────────────────────────

  Widget _buildMap() {
    return BlocBuilder<DriverHomeBloc, DriverHomeState>(
      buildWhen: (prev, curr) =>
          prev.driverLat != curr.driverLat ||
          prev.isAvailable != curr.isAvailable ||
          prev.heatmapCells != curr.heatmapCells,
      builder: (context, state) {
        final markers = <Marker>{};
        if (state.driverLat != null && state.driverLng != null) {
          markers.add(Marker(
            markerId: const MarkerId('driver'),
            position: LatLng(state.driverLat!, state.driverLng!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
                title: AppLocalizations.of(context)!.yourLocation),
          ));
        }

        // Build heatmap hexagons from HeatmapService data
        final hexagons = _buildHeatmapHexagons(state.heatmapCells);

        // Use the current driver position as initial camera if available,
        // otherwise fall back to Riyadh center.
        final initialCamera = (state.driverLat != null &&
                state.driverLng != null)
            ? CameraPosition(
                target: LatLng(state.driverLat!, state.driverLng!),
                zoom: 15,
              )
            : _defaultCamera;

        return GoogleMap(
          initialCameraPosition: initialCamera,
          onMapCreated: (ctrl) {
            // Always update the controller reference — it gets recreated
            // when the widget rebuilds after navigation back.
            _mapController?.dispose();
            _mapController = ctrl;

            // Reset last animated position so next location update moves camera
            _lastAnimatedLat = null;
            _lastAnimatedLng = null;

            // Immediately move to driver's actual position if we have it
            final s = context.read<DriverHomeBloc>().state;
            if (s.driverLat != null && s.driverLng != null) {
              Future.microtask(
                  () => _animateTo(s.driverLat!, s.driverLng!));
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: markers,
          polygons: hexagons,
          padding: const EdgeInsets.only(bottom: _bottomSheetHeight + 8),
          style: Theme.of(context).brightness == Brightness.dark
              ? kDarkMapStyle
              : kLightMapStyle,
        );
      },
    );
  }

  /// Build heatmap visualization as tessellating hexagons.
  static const double _hexRadiusMeters = HeatmapService.hexRadiusMeters;

  Set<Polygon> _buildHeatmapHexagons(List<HeatmapCell> cells) {
    return cells.map((cell) {
      Color fillColor;
      Color strokeColor;

      switch (cell.level) {
        case HeatmapLevel.high:
          fillColor = const Color(0xFFE53935).withValues(alpha: 0.35);
          strokeColor = const Color(0xFFE53935).withValues(alpha: 0.60);
          break;
        case HeatmapLevel.medium:
          fillColor = const Color(0xFFF57C00).withValues(alpha: 0.25);
          strokeColor = const Color(0xFFF57C00).withValues(alpha: 0.50);
          break;
        case HeatmapLevel.low:
          fillColor = const Color(0xFFFFF176).withValues(alpha: 0.16);
          strokeColor = const Color(0xFFFFF176).withValues(alpha: 0.35);
          break;
      }

      final vertices = _hexagonVertices(
        cell.centerLat,
        cell.centerLng,
        _hexRadiusMeters,
      );

      return Polygon(
        polygonId: PolygonId('hex_${cell.cellId}'),
        points: vertices,
        fillColor: fillColor,
        strokeColor: strokeColor,
        strokeWidth: 1,
      );
    }).toSet();
  }

  // FIX P3-06: Pre-computed sin/cos for hexagon vertices (60° increments).
  // Avoids redundant trig calculations on every frame rebuild.
  static final List<double> _hexSin = [
    math.sin(0 * math.pi / 180.0),
    math.sin(60 * math.pi / 180.0),
    math.sin(120 * math.pi / 180.0),
    math.sin(180 * math.pi / 180.0),
    math.sin(240 * math.pi / 180.0),
    math.sin(300 * math.pi / 180.0),
  ];
  static final List<double> _hexCos = [
    math.cos(0 * math.pi / 180.0),
    math.cos(60 * math.pi / 180.0),
    math.cos(120 * math.pi / 180.0),
    math.cos(180 * math.pi / 180.0),
    math.cos(240 * math.pi / 180.0),
    math.cos(300 * math.pi / 180.0),
  ];

  List<LatLng> _hexagonVertices(
      double lat, double lng, double radiusMeters) {
    final latPerMeter = 1.0 / 111320.0;
    final lngPerMeter =
        1.0 / (111320.0 * math.cos(lat * math.pi / 180.0));

    final vertices = <LatLng>[];
    for (int i = 0; i < 6; i++) {
      final dLat = radiusMeters * _hexSin[i] * latPerMeter;
      final dLng = radiusMeters * _hexCos[i] * lngPerMeter;
      vertices.add(LatLng(lat + dLat, lng + dLng));
    }
    return vertices;
  }

  // ─── Top Bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _topBarHorizontalPadding,
          vertical: _topBarVerticalPadding,
        ),
        child: Row(
          children: [
            MapButton(
              icon: Icons.menu_rounded,
              size: _mapButtonSize,
              borderRadius: _mapButtonRadius,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            const Spacer(),
            MapButton(
              icon: Icons.notifications_outlined,
              size: _mapButtonSize,
              borderRadius: _mapButtonRadius,
              onTap: () => context.push(AppRoutes.driverNotifications),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Location Button ──────────────────────────────────────────────────────

  Widget _buildLocationButton() {
    return Positioned(
      bottom: _bottomSheetHeight + 16,
      right: 18,
      child: MapButton(
        icon: Icons.my_location_rounded,
        size: _mapButtonSize,
        borderRadius: _mapButtonRadius,
        onTap: () {
          final s = context.read<DriverHomeBloc>().state;
          if (s.driverLat != null && s.driverLng != null) {
            // Force re-animate even if same position
            _lastAnimatedLat = null;
            _lastAnimatedLng = null;
            _animateTo(s.driverLat!, s.driverLng!);
          }
        },
      ),
    );
  }

  // ─── Bottom Panel ─────────────────────────────────────────────────────────

  Widget _buildBottomPanel() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: BottomSheetContainer(
        child: BlocBuilder<DriverHomeBloc, DriverHomeState>(
          builder: (context, state) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAvailabilityToggle(context, state),
                const SizedBox(height: 16),
                _buildStatsRow(state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAvailabilityToggle(
      BuildContext context, DriverHomeState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: state.isAvailable ? AppColors.success : context.divColor,
          width: state.isAvailable ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: state.isAvailable
                      ? AppColors.success
                      : context.textDisabled,
                  shape: BoxShape.circle,
                  boxShadow: state.isAvailable
                      ? [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                state.isAvailable
                    ? AppLocalizations.of(context)!.availableForTrips
                    : AppLocalizations.of(context)!.unavailable,
                style: TextStyle(
                  color: state.isAvailable
                      ? AppColors.success
                      : context.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          state.isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: AppColors.primary),
                )
              : Switch(
                  value: state.isAvailable,
                  onChanged: (v) => context
                      .read<DriverHomeBloc>()
                      .add(ToggleAvailability(v)),
                  activeThumbColor: AppColors.success,
                  inactiveThumbColor: context.textDisabled,
                ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(DriverHomeState state) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: AppLocalizations.of(context)!.trips,
            value: '${state.totalTrips}',
            icon: Icons.directions_car_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: AppLocalizations.of(context)!.earnings,
            value:
                '${state.totalEarnings.toStringAsFixed(0)} ${AppLocalizations.of(context)!.currencySar}',
            icon: Icons.payments_rounded,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: AppLocalizations.of(context)!.rating,
            value: state.rating.toStringAsFixed(1),
            icon: Icons.star_rounded,
          ),
        ),
      ],
    );
  }

  // ─── Drawer ───────────────────────────────────────────────────────────────

  Widget _buildDrawer(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    return AppDrawer(
      user: user,
      onTripsTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.driverTrips);
      },
      onMessagesTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.driverMessages);
      },
      onChatbotTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.driverChatbot);
      },
      onComplaintsTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.driverComplaints);
      },
      onProfileTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.driverProfile);
      },
      onLogout: () {
        Navigator.pop(context);
        context.read<AuthBloc>().add(SignOutRequested());
      },
    );
  }
}

