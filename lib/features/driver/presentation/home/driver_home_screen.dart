import 'dart:async';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'bloc/driver_home_bloc.dart';
import 'bloc/driver_home_event.dart';
import 'bloc/driver_home_state.dart';
import '../../../../core/constants/map_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/map_button.dart';
import '../../../../core/widgets/location_permission_cta.dart';
import '../../../../core/bloc/location_permission_cubit.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../services/supabase_service.dart';
import '../../../../services/heatmap_service.dart';
import '../../../../core/widgets/custom_animated_bottom_nav.dart';
import '../../../../services/directions_service.dart';
import '../../../../core/constants/env_constants.dart';
import '../widgets/driver_offer_overlay.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _bottomNavIndex = -1;

  static const _defaultCamera = CameraPosition(
    target: AppConstants.defaultMapCenter,
    zoom: 15,
  );

  double? _lastAnimatedLat;
  double? _lastAnimatedLng;
  bool _initialized = false;

  // ── Corridor polyline drawn on home map ─────────────────────────────────────
  Set<Polyline> _corridorPolylines = {};
  Set<Marker> _corridorMarkers = {};

  static const double _bottomSheetHeight = 236.0;
  static const double _mapButtonSize = 48.0;
  static const double _mapButtonRadius = 14.0;
  static const double _topBarHorizontalPadding = 18.0;
  static const double _topBarVerticalPadding = 14.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<LocationPermissionCubit>().check();
    // Load any saved corridor from DB and draw on map
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCorridorFromDb());
  }

  Future<void> _loadCorridorFromDb() async {
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid == null) return;
      final row = await SupabaseService.client
          .from('drivers_profile')
          .select(
              'target_origin_lat, target_origin_lng, target_dest_lat, target_dest_lng')
          .eq('id', uid)
          .maybeSingle();
      if (row == null) return;
      final oLat = (row['target_origin_lat'] as num?)?.toDouble();
      final oLng = (row['target_origin_lng'] as num?)?.toDouble();
      final dLat = (row['target_dest_lat'] as num?)?.toDouble();
      final dLng = (row['target_dest_lng'] as num?)?.toDouble();
      if (oLat != null && oLng != null && dLat != null && dLng != null) {
        _drawCorridorPolyline(LatLng(oLat, oLng), LatLng(dLat, dLng));
      }
    } catch (e) {
      debugPrint('⚠️ DriverHome: loadCorridor failed: $e');
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;
      context.read<DriverHomeBloc>().add(LoadDriverStatus());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check location permission when returning from Settings
      context.read<LocationPermissionCubit>().recheck();

      final bloc = context.read<DriverHomeBloc>();
      if (bloc.state.isAvailable) {
        bloc.add(RefreshDriverLocation());
      }
    }
  }

  Future<void> _animateTo(double lat, double lng) async {
    if (_mapController == null) return;

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
      child: MultiBlocListener(
        listeners: [
          BlocListener<DriverHomeBloc, DriverHomeState>(
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
          ),
          BlocListener<DriverHomeBloc, DriverHomeState>(
            listenWhen: (prev, curr) =>
                prev.errorMessage != curr.errorMessage &&
                curr.errorMessage != null,
            listener: (context, state) {
              if (state.errorMessage != null &&
                  state.errorMessage!.isNotEmpty) {
                final l = AppLocalizations.of(context)!;
                final msg = switch (state.errorMessage) {
                  'errorCannotGoOnlineDuringTrip' =>
                    l.errorCannotGoOnlineDuringTrip,
                  'errorUnexpected' => l.errorUnexpected,
                  _ => state.errorMessage!,
                };
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
          ),
        ],
        child: DriverOfferOverlay(
          child: Scaffold(
            key: _scaffoldKey,
            extendBody: true,
            backgroundColor: context.bgColor,
            drawer: _buildDrawer(context),
            body: Stack(
              children: [
                _buildMap(),
                _buildTopBar(),
                _buildLocationButton(),
              ],
            ),
            bottomNavigationBar: _buildBottomNav(),
          ),
        ),
      ),
    );
  }

  Widget _buildMap() {
    return BlocBuilder<DriverHomeBloc, DriverHomeState>(
      buildWhen: (prev, curr) =>
          prev.driverLat != curr.driverLat ||
          prev.isAvailable != curr.isAvailable ||
          prev.heatmapCells != curr.heatmapCells,
      builder: (context, state) {
        final markers = <Marker>{..._corridorMarkers};
        final hexagons = _buildHeatmapHexagons(state.heatmapCells);
        final initialCamera =
            (state.driverLat != null && state.driverLng != null)
                ? CameraPosition(
                    target: LatLng(state.driverLat!, state.driverLng!),
                    zoom: 15)
                : _defaultCamera;

        return GoogleMap(
          initialCameraPosition: initialCamera,
          onMapCreated: (ctrl) {
            _mapController = ctrl;
            _lastAnimatedLat = null;
            _lastAnimatedLng = null;
            final s = context.read<DriverHomeBloc>().state;
            if (s.driverLat != null && s.driverLng != null) {
              Future.microtask(() => _animateTo(s.driverLat!, s.driverLng!));
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          markers: markers,
          polygons: hexagons,
          polylines: _corridorPolylines, // ✅ corridor drawn here
          padding: const EdgeInsets.only(bottom: 24, top: 100),
          style: Theme.of(context).brightness == Brightness.dark
              ? kDarkMapStyle
              : kLightMapStyle,
        );
      },
    );
  }

  static const double _hexRadiusMeters = 300.0;

  Set<Polygon> _buildHeatmapHexagons(List<HeatmapCell> cells) {
    return cells.map((cell) {
      Color fillColor;
      Color strokeColor;

      switch (cell.level) {
        case HeatmapLevel.high:
          fillColor = AppColors.error.withValues(alpha: 0.35);
          strokeColor = AppColors.error.withValues(alpha: 0.60);
          break;
        case HeatmapLevel.medium:
          fillColor = AppColors.warning.withValues(alpha: 0.25);
          strokeColor = AppColors.warning.withValues(alpha: 0.50);
          break;
        case HeatmapLevel.low:
          fillColor = AppColors.warningLight.withValues(alpha: 0.16);
          strokeColor = AppColors.warningLight.withValues(alpha: 0.35);
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

  List<LatLng> _hexagonVertices(double lat, double lng, double radiusMeters) {
    final latPerMeter = 1.0 / 111320.0;
    final lngPerMeter = 1.0 / (111320.0 * math.cos(lat * math.pi / 180.0));

    final vertices = <LatLng>[];
    for (int i = 0; i < 6; i++) {
      final dLat = radiusMeters * _hexSin[i] * latPerMeter;
      final dLng = radiusMeters * _hexCos[i] * lngPerMeter;
      vertices.add(LatLng(lat + dLat, lng + dLng));
    }
    return vertices;
  }

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
            BlocBuilder<DriverHomeBloc, DriverHomeState>(
              builder: (context, state) {
                return GestureDetector(
                  onTap: () => context.push(AppRoutes.driverWallet),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.elevatedColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.white.withValues(alpha: 0.08)
                              : AppColors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.priceWithCurrency(
                              state.availableBalance.toStringAsFixed(0),
                              AppLocalizations.of(context)!.egp),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded,
                            color: context.textSecondary, size: 16),
                      ],
                    ),
                  ),
                );
              },
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

  Widget _buildLocationButton() {
    return Positioned(
      bottom: 20,
      right: 16,
      child: MapButton(
        icon: Icons.my_location_rounded,
        size: _mapButtonSize,
        borderRadius: _mapButtonRadius,
        onTap: () {
          final s = context.read<DriverHomeBloc>().state;
          if (s.driverLat != null && s.driverLng != null) {
            _lastAnimatedLat = null;
            _lastAnimatedLng = null;
            _animateTo(s.driverLat!, s.driverLng!);
          }
        },
      ),
    );
  }

  Widget _buildBottomNav() {
    final l = AppLocalizations.of(context)!;
    return CustomAnimatedBottomNav(
      items: [
        BottomNavItem(
          icon: Icons.list_alt_outlined,
          activeIcon: Icons.list_alt_rounded,
          label: l.trips,
        ),
        BottomNavItem(
          icon: Icons.alt_route_outlined,
          activeIcon: Icons.alt_route_rounded,
          label: l.destination,
        ),
      ],
      onTap: (index) {
        if (index == 0) {
          context.push(AppRoutes.driverRequestFeed); // ✅ real-time request feed
        } else if (index == 1) {
          _showCorridorPicker(context);
        }
      },
      itemColor: context.textSecondary,
      backgroundColor: context.cardColor,
      notchColor: AppColors.transparent,
      notchRadius: 42,
      gapWidth: 90,
      floatingActionButton: _buildGoButtonInner(),
    );
  }

  void _showCorridorPicker(BuildContext context) {
    final bloc = context.read<DriverHomeBloc>();
    final lat = bloc.state.driverLat ?? AppConstants.defaultMapCenter.latitude;
    final lng = bloc.state.driverLng ?? AppConstants.defaultMapCenter.longitude;
    Navigator.push<Map<String, LatLng>>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CorridorPickerScreen(
          initialCenter: LatLng(lat, lng),
        ),
      ),
    ).then((result) {
      if (result == null) return;
      if (result.containsKey('cleared')) {
        // User cleared the corridor
        if (mounted)
          setState(() {
            _corridorPolylines = {};
            _corridorMarkers = {};
          });
        return;
      }
      final origin = result['origin']!;
      final dest = result['dest']!;
      _drawCorridorPolyline(origin, dest);
    });
  }

  Future<void> _drawCorridorPolyline(LatLng origin, LatLng dest) async {
    if (!mounted) return;

    // Show markers immediately
    setState(() {
      _corridorPolylines = {};
      _corridorMarkers = {
        Marker(
          markerId: const MarkerId('corr_origin'),
          position: origin,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'بداية الممر'),
        ),
        Marker(
          markerId: const MarkerId('corr_dest'),
          position: dest,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'نهاية الممر'),
        ),
      };
    });

    // Fetch real route
    final result = await DirectionsService.getRoute(
      originLat: origin.latitude,
      originLng: origin.longitude,
      destLat: dest.latitude,
      destLng: dest.longitude,
      apiKey: EnvConstants.googleMapsApiKey,
    );

    if (!mounted || result == null || result.points.isEmpty) return;

    final points = result.points;

    setState(() {
      _corridorPolylines = {
        // Outer glowing line
        Polyline(
          polylineId: const PolylineId('corridor_glow'),
          points: points,
          color: AppColors.primary.withValues(alpha: 0.3),
          width: 12,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
        // Inner core line
        Polyline(
          polylineId: const PolylineId('corridor_core'),
          points: points,
          color: AppColors.primary,
          width: 4,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      };
    });

    // Fit camera to polyline
    if (_mapController != null) {
      final lats = points.map((p) => p.latitude);
      final lngs = points.map((p) => p.longitude);
      final sw = LatLng(lats.reduce(math.min), lngs.reduce(math.min));
      final ne = LatLng(lats.reduce(math.max), lngs.reduce(math.max));
      Future.delayed(const Duration(milliseconds: 300), () {
        _mapController?.animateCamera(
          CameraUpdate.newLatLngBounds(
            LatLngBounds(southwest: sw, northeast: ne),
            60,
          ),
        );
      });
    }
  }

  Widget _buildGoButtonInner() {
    return BlocBuilder<LocationPermissionCubit, LocationPermissionState>(
      builder: (context, permState) {
        // ── Location blocked → show CTA button instead of GO ──
        if (permState.isBlocked) {
          return LocationPermissionCta(
            variant: LocationCtaVariant.button,
            onGranted: () {
              // Re-load driver status when permission is granted
              context.read<DriverHomeBloc>().add(LoadDriverStatus());
            },
          );
        }

        // ── Normal GO button ──
        return BlocBuilder<DriverHomeBloc, DriverHomeState>(
          builder: (context, state) {
            final isOnline = state.isAvailable;
            final isLoading = state.isLoading;

            return GestureDetector(
              onTap: isLoading
                  ? null
                  : () {
                      context
                          .read<DriverHomeBloc>()
                          .add(ToggleAvailability(!isOnline));
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.fastOutSlowIn,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: isOnline
                        ? [
                            AppColors.success,
                            AppColors.success,
                          ]
                        : [
                            AppColors.error,
                            AppColors.error,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.25),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isOnline ? AppColors.success : AppColors.error)
                          .withValues(alpha: 0.5),
                      blurRadius: isOnline ? 25 : 15,
                      spreadRadius: isOnline ? 8 : 2,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Center(
                  child: isLoading
                      ? const CircularProgressIndicator(
                          color: AppColors.white, strokeWidth: 3)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isOnline
                                  ? Icons.sensors_rounded
                                  : Icons.power_settings_new_rounded,
                              color: AppColors.white,
                              size: 26,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isOnline
                                  ? AppLocalizations.of(context)!.onlineStatus
                                  : AppLocalizations.of(context)!.offlineStatus,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 12.5,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final user = authState is AuthAuthenticated ? authState.user : null;
    return AppDrawer(
      user: user,
      onProfileTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.driverProfile);
      },
      onWalletTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.driverWallet);
      },
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
      onLogout: () {
        Navigator.pop(context);
        context.read<DriverHomeBloc>().add(ResetDriverStatus());
        context.read<AuthBloc>().add(SignOutRequested());
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CORRIDOR PICKER SCREEN  — two-tap free selection
// ═══════════════════════════════════════════════════════════════════════════

class _CorridorPickerScreen extends StatefulWidget {
  final LatLng initialCenter;
  const _CorridorPickerScreen({required this.initialCenter});

  @override
  State<_CorridorPickerScreen> createState() => _CorridorPickerScreenState();
}

class _CorridorPickerScreenState extends State<_CorridorPickerScreen> {
  // Tap step: 0 = waiting for origin, 1 = waiting for dest, 2 = done
  int _step = 0;

  GoogleMapController? _mapCtrl;
  final TextEditingController _searchCtrl = TextEditingController();

  LatLng? _originPt;
  LatLng? _destPt;
  String? _originAddr;
  String? _destAddr;
  double _originRadiusKm = 2.0;
  double _destRadiusKm = 3.0;
  bool _isResolving = false;
  bool _isSaving = false;

  List<LatLng> _routePoints = [];

  @override
  void initState() {
    super.initState();
    _loadExistingCorridor();
  }

  Future<void> _loadExistingCorridor() async {
    setState(() => _isResolving = true);
    try {
      final uid = SupabaseService.currentUser?.id;
      if (uid != null) {
        final row = await SupabaseService.client
            .from('drivers_profile')
            .select(
                'target_origin_lat, target_origin_lng, target_dest_lat, target_dest_lng, target_origin_radius_km, target_route_radius_km')
            .eq('id', uid)
            .maybeSingle();

        if (row != null) {
          final oLat = (row['target_origin_lat'] as num?)?.toDouble();
          final oLng = (row['target_origin_lng'] as num?)?.toDouble();
          final dLat = (row['target_dest_lat'] as num?)?.toDouble();
          final dLng = (row['target_dest_lng'] as num?)?.toDouble();

          if (oLat != null && oLng != null && dLat != null && dLng != null) {
            _originPt = LatLng(oLat, oLng);
            _destPt = LatLng(dLat, dLng);
            _originRadiusKm =
                (row['target_origin_radius_km'] as num?)?.toDouble() ?? 2.0;
            _destRadiusKm =
                (row['target_route_radius_km'] as num?)?.toDouble() ?? 3.0;
            _step = 2; // both points set

            // try to get addresses
            try {
              final oMarks = await placemarkFromCoordinates(oLat, oLng);
              if (oMarks.isNotEmpty)
                _originAddr =
                    '${oMarks.first.street ?? ''}, ${oMarks.first.locality ?? ''}';
              final dMarks = await placemarkFromCoordinates(dLat, dLng);
              if (dMarks.isNotEmpty)
                _destAddr =
                    '${dMarks.first.street ?? ''}, ${dMarks.first.locality ?? ''}';
            } catch (_) {}

            _fetchAndDrawRoute();
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading corridor: $e');
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isResolving = true);
    try {
      final locs = await locationFromAddress(query);
      if (locs.isNotEmpty) {
        final ll = LatLng(locs.first.latitude, locs.first.longitude);
        _mapCtrl?.animateCamera(CameraUpdate.newLatLngZoom(ll, 14));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('لم يتم العثور على المكان'),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isResolving = false);
    }
  }

  Future<void> _onMapTap(LatLng ll) async {
    if (_step > 1 || _isSaving) return;
    setState(() => _isResolving = true);

    String? address;
    try {
      final placemarks =
          await placemarkFromCoordinates(ll.latitude, ll.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        address = '${p.street ?? ''}, ${p.locality ?? ''}';
      }
    } catch (_) {
      address =
          '${ll.latitude.toStringAsFixed(4)}, ${ll.longitude.toStringAsFixed(4)}';
    }

    setState(() {
      if (_step == 0) {
        _originPt = ll;
        _originAddr = address;
        _step = 1;
      } else {
        _destPt = ll;
        _destAddr = address;
        _step = 2;
        _fetchAndDrawRoute();
      }
      _isResolving = false;
    });
  }

  Future<void> _fetchAndDrawRoute() async {
    if (_originPt == null || _destPt == null) return;
    final result = await DirectionsService.getRoute(
      originLat: _originPt!.latitude,
      originLng: _originPt!.longitude,
      destLat: _destPt!.latitude,
      destLng: _destPt!.longitude,
      apiKey: EnvConstants.googleMapsApiKey,
    );
    if (!mounted || result == null) return;
    setState(() {
      _routePoints = result.points;
    });

    final lats = _routePoints.map((p) => p.latitude);
    final lngs = _routePoints.map((p) => p.longitude);
    final sw = LatLng(lats.reduce(math.min), lngs.reduce(math.min));
    final ne = LatLng(lats.reduce(math.max), lngs.reduce(math.max));
    _mapCtrl?.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne), 60));
  }

  void _reset() => setState(() {
        _step = 0;
        _originPt = null;
        _destPt = null;
        _originAddr = null;
        _destAddr = null;
        _routePoints = [];
      });

  Future<void> _save() async {
    if (_originPt == null || _destPt == null) return;
    setState(() => _isSaving = true);
    try {
      // Use the dedicated RPC so server-side validation runs correctly
      await SupabaseService.client.rpc('set_driver_target_route', params: {
        'p_driver_id': SupabaseService.currentUser!.id,
        'p_origin_lat': _originPt!.latitude,
        'p_origin_lng': _originPt!.longitude,
        'p_dest_lat': _destPt!.latitude,
        'p_dest_lng': _destPt!.longitude,
        'p_origin_radius_km': _originRadiusKm,
        'p_dest_radius_km': _destRadiusKm,
      });

      if (mounted) {
        Navigator.pop<Map<String, LatLng>>(context, {
          'origin': _originPt!,
          'dest': _destPt!,
        });
      }
    } catch (e) {
      // Fallback: direct write if RPC not found / signature changed
      try {
        await SupabaseService.client.from('drivers_profile').update({
          'target_origin_lat': _originPt!.latitude,
          'target_origin_lng': _originPt!.longitude,
          'target_dest_lat': _destPt!.latitude,
          'target_dest_lng': _destPt!.longitude,
          'target_origin_radius_km': _originRadiusKm,
          'target_route_radius_km': _destRadiusKm,
        }).eq('id', SupabaseService.currentUser!.id);
        if (mounted) {
          Navigator.pop<Map<String, LatLng>>(context, {
            'origin': _originPt!,
            'dest': _destPt!,
          });
        }
      } catch (e2) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('خطأ: $e2'),
                backgroundColor: AppColors.error),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clear() async {
    try {
      await SupabaseService.client.from('drivers_profile').update({
        'target_origin_lat': null,
        'target_origin_lng': null,
        'target_dest_lat': null,
        'target_dest_lng': null,
      }).eq('id', SupabaseService.currentUser!.id);

      if (mounted) {
        Navigator.pop<Map<String, LatLng>>(context, {'cleared': LatLng(0, 0)});
      }
    } catch (e) {
      debugPrint('CorridorPicker: clear failed $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? AppColors.background : AppColors.white;

    // Step instruction text
    final String hintText = _step == 0
        ? '① اضغط على نقطة بداية الممر (الانطلاق)'
        : _step == 1
            ? '② اضغط على نقطة نهاية الممر (الوجهة)'
            : 'تم تحديد الممر — راجع التفاصيل وحفظه';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: panelColor.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.26),
                    blurRadius: 8)
              ],
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 17,
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.7)
                    : AppColors.black.withValues(alpha: 0.87)),
          ),
        ),
        actions: [
          if (_step > 0)
            GestureDetector(
              onTap: _reset,
              child: Container(
                margin: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('إعادة',
                    style: TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          GestureDetector(
            onTap: _clear,
            child: Container(
              margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('مسح',
                  style: TextStyle(
                      color: AppColors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      body: Stack(children: [
        // ── Map ──────────────────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition:
              CameraPosition(target: widget.initialCenter, zoom: 13),
          onMapCreated: (ctrl) => _mapCtrl = ctrl,
          onTap: _onMapTap,
          style: isDark ? kDarkMapStyle : kLightMapStyle,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          circles: {
            if (_originPt != null)
              Circle(
                circleId: const CircleId('origin_zone'),
                center: _originPt!,
                radius: _originRadiusKm * 1000,
                fillColor: AppColors.success.withValues(alpha: 0.12),
                strokeColor: AppColors.success.withValues(alpha: 0.8),
                strokeWidth: 2,
              ),
            if (_destPt != null)
              Circle(
                circleId: const CircleId('dest_zone'),
                center: _destPt!,
                radius: _destRadiusKm * 1000,
                fillColor: AppColors.primary.withValues(alpha: 0.12),
                strokeColor: AppColors.primary.withValues(alpha: 0.8),
                strokeWidth: 2,
              ),
          },
          polylines: _routePoints.isNotEmpty
              ? {
                  // Outer glowing line
                  Polyline(
                    polylineId: const PolylineId('corridor_glow'),
                    points: _routePoints,
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 12,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                  ),
                  // Inner core line
                  Polyline(
                    polylineId: const PolylineId('corridor_core'),
                    points: _routePoints,
                    color: AppColors.primary,
                    width: 4,
                    startCap: Cap.roundCap,
                    endCap: Cap.roundCap,
                    jointType: JointType.round,
                  ),
                }
              : (_originPt != null && _destPt != null)
                  ? {
                      Polyline(
                        polylineId: const PolylineId('corridor_straight'),
                        points: [_originPt!, _destPt!],
                        color: AppColors.primary.withValues(alpha: 0.5),
                        width: 3,
                        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
                      ),
                    }
                  : {},
          markers: {
            if (_originPt != null)
              Marker(
                markerId: const MarkerId('origin'),
                position: _originPt!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen),
                infoWindow:
                    InfoWindow(title: 'بداية الممر', snippet: _originAddr),
              ),
            if (_destPt != null)
              Marker(
                markerId: const MarkerId('dest'),
                position: _destPt!,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueBlue),
                infoWindow:
                    InfoWindow(title: 'نهاية الممر', snippet: _destAddr),
              ),
          },
        ),

        // ── Search Bar ──────────────────────────────────────────────────────
        Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 16,
          right: 16,
          child: Container(
            decoration: BoxDecoration(
              color: panelColor.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.26),
                    blurRadius: 10)
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Icon(Icons.search_rounded, color: AppColors.grey, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن منطقة للذهاب إليها...',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.grey),
                    border: InputBorder.none,
                  ),
                  style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.white : AppColors.black),
                  onSubmitted: _searchLocation,
                ),
              ),
              if (_isResolving)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2)),
            ]),
          ),
        ),

        // ── Step hint banner ────────────────────────────────────────────────
        if (!_isResolving)
          Positioned(
            top: MediaQuery.of(context).padding.top + 120,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _step == 2
                    ? AppColors.success.withValues(alpha: 0.92)
                    : AppColors.black.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.26),
                      blurRadius: 10)
                ],
              ),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(
                  _step == 2
                      ? Icons.check_circle_rounded
                      : Icons.touch_app_rounded,
                  color: AppColors.white.withValues(alpha: 0.7),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Flexible(
                    child: Text(hintText,
                        style: const TextStyle(
                            color: AppColors.white, fontSize: 13),
                        textAlign: TextAlign.center)),
              ]),
            ),
          ),

        if (_isResolving)
          Positioned(
            top: MediaQuery.of(context).padding.top + 120,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: AppColors.white, strokeWidth: 2)),
                    SizedBox(width: 10),
                    Text('جاري المعالجة...',
                        style: TextStyle(color: AppColors.white, fontSize: 13)),
                  ]),
            ),
          ),

        // ── Bottom panel ────────────────────────────────────────────────────
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: panelColor,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.38),
                    blurRadius: 20,
                    offset: Offset(0, -4))
              ],
            ),
            padding: EdgeInsets.fromLTRB(
                20, 14, 20, MediaQuery.of(context).padding.bottom + 20),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.grey.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(100)))),
                  const SizedBox(height: 14),

                  // Origin + Dest chips
                  Row(children: [
                    _PointChip(
                      step: 1,
                      currentStep: _step,
                      color: AppColors.success,
                      icon: Icons.trip_origin_rounded,
                      label: 'نقطة الانطلاق',
                      address: _originAddr,
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward_rounded,
                          size: 16, color: AppColors.grey),
                    ),
                    _PointChip(
                      step: 2,
                      currentStep: _step,
                      color: AppColors.primary,
                      icon: Icons.flag_rounded,
                      label: 'نقطة الوصول',
                      address: _destAddr,
                    ),
                  ]),

                  // Sliders — only visible when both points are set
                  if (_step == 2) ...[
                    const SizedBox(height: 16),
                    _RadiusSlider(
                      label: 'نطاق الانطلاق',
                      color: AppColors.success,
                      value: _originRadiusKm,
                      min: 0.5,
                      max: 10.0,
                      onChanged: (v) => setState(() => _originRadiusKm = v),
                    ),
                    const SizedBox(height: 8),
                    _RadiusSlider(
                      label: 'نطاق الوجهة',
                      color: AppColors.primary,
                      value: _destRadiusKm,
                      min: 0.5,
                      max: 15.0,
                      onChanged: (v) => setState(() => _destRadiusKm = v),
                    ),
                  ],

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (_step == 2 && !_isSaving && !_isResolving)
                          ? _save
                          : null,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.white))
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _step == 0
                            ? 'حدد نقطة الانطلاق أولاً'
                            : _step == 1
                                ? 'حدد نقطة الوصول'
                                : 'حفظ الممر المفضل',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.grey,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ]),
          ),
        ),
      ]),
    );
  }
}

class _PointChip extends StatelessWidget {
  final int step;
  final int currentStep;
  final Color color;
  final IconData icon;
  final String label;
  final String? address;
  const _PointChip(
      {required this.step,
      required this.currentStep,
      required this.color,
      required this.icon,
      required this.label,
      this.address});

  @override
  Widget build(BuildContext context) {
    final bool isDone = currentStep >= step;
    final bool isActive = currentStep == step - 1;
    return Expanded(
        child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDone
            ? color.withValues(alpha: 0.12)
            : isActive
                ? color.withValues(alpha: 0.06)
                : AppColors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDone
                ? color.withValues(alpha: 0.5)
                : AppColors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        Icon(icon, color: isDone ? color : AppColors.grey, size: 16),
        const SizedBox(width: 6),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isDone ? color : AppColors.grey)),
          if (address != null)
            Text(address!,
                style: const TextStyle(fontSize: 9, color: AppColors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis)
          else
            Text(isActive ? 'اضغط على الخريطة' : '---',
                style: const TextStyle(fontSize: 9, color: AppColors.grey)),
        ])),
      ]),
    ));
  }
}

class _RadiusSlider extends StatelessWidget {
  final String label;
  final Color color;
  final double value;
  final double min;
  final double max;
  final bool enabled;
  final ValueChanged<double> onChanged;

  const _RadiusSlider({
    required this.label,
    required this.color,
    required this.value,
    required this.min,
    required this.max,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(
        width: 110,
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: enabled ? null : AppColors.grey)),
      ),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: enabled ? color : AppColors.grey,
            inactiveTrackColor: AppColors.grey.withValues(alpha: 0.2),
            thumbColor: enabled ? color : AppColors.grey,
            overlayColor: color.withValues(alpha: 0.1),
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: ((max - min) / 0.5).round(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ),
      SizedBox(
        width: 44,
        child: Text('${value.toStringAsFixed(1)} كم',
            style: TextStyle(
                fontSize: 10,
                color: enabled ? color : AppColors.grey,
                fontWeight: FontWeight.w700),
            textAlign: TextAlign.end),
      ),
    ]);
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.3),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5))),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]);
}
