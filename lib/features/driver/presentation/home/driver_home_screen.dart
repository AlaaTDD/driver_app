import 'dart:async';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bloc/driver_home_bloc.dart';
import 'bloc/driver_home_event.dart';
import 'bloc/driver_home_state.dart';
import '../../../../core/map/app_map.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/map_button.dart';
import '../../../../core/widgets/location_permission_cta.dart';
import '../../../../core/bloc/location_permission_cubit.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/services/heatmap_service.dart';
import '../../../../core/widgets/custom_animated_bottom_nav.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/constants/env_constants.dart';
import '../widgets/driver_offer_overlay.dart';
import '../../../../core/utils/map_camera_utils.dart';
import 'widgets/neon_route_polyline.dart';
import '../corridor/corridor_picker_screen.dart';
import 'package:snapix/core/utils/app_logger.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const _corridorNeonLoopDuration = Duration(milliseconds: 3200);
  static const _corridorNeonFrameInterval = Duration(milliseconds: 33);
  static const _corridorNeonCoreWidth = 5;
  static const _corridorNeonGlowWidth = 13;
  static const _corridorNeonHaloWidth = 22;
  static const double _mapBottomPadding = 126.0;
  static const double _mapTopPadding = 100.0;

  GoogleMapController? _mapController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static CameraPosition get _defaultCamera => CameraPosition(
        target: AppConstants.defaultMapCenter,
        zoom: 15,
      );

  double? _lastAnimatedLat;
  double? _lastAnimatedLng;
  bool _initialized = false;

  // ── Corridor polyline drawn on home map ─────────────────────────────────────
  Set<Polyline> _corridorPolylines = {};
  Set<Marker> _corridorMarkers = {};
  List<LatLng> _corridorRoutePoints = [];
  bool _corridorCameraFitted = false;
  bool _corridorCameraFitInFlight = false;
  late final AnimationController _corridorNeonCtrl;
  Duration _lastCorridorNeonFrame = Duration.zero;

  // ── Heatmap fade-in ناعم عند التحديث (يمنع القفزة المفاجئة في الألوان) ────
  late final AnimationController _heatmapFadeCtrl;
  double _heatmapAlpha = 1.0;
  List<HeatmapCell> _renderedHeatmapCells = const [];

  static const double _mapButtonSize = 48.0;
  static const double _mapButtonRadius = 14.0;
  static const double _topBarHorizontalPadding = 18.0;
  static const double _topBarVerticalPadding = 14.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _corridorNeonCtrl = AnimationController(
      vsync: this,
      duration: _corridorNeonLoopDuration,
    )..addListener(_onCorridorNeonFrame);
    _heatmapFadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(_onHeatmapFadeFrame);
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
      AppLogger.warning('DriverHome: loadCorridor failed: $e');
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

    _corridorNeonCtrl.dispose();
    _heatmapFadeCtrl.dispose();
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  void _onCorridorNeonFrame() {
    if (_corridorRoutePoints.length < 2) return;
    final elapsed = _corridorNeonCtrl.lastElapsedDuration ?? Duration.zero;
    if (elapsed - _lastCorridorNeonFrame < _corridorNeonFrameInterval) return;
    _lastCorridorNeonFrame = elapsed;
    if (!mounted) return;
    setState(() => _corridorPolylines = _buildCorridorNeonPolylines());
  }

  void _restartCorridorNeonLoop() {
    if (_corridorRoutePoints.length < 2) {
      _stopCorridorNeonLoop();
      return;
    }
    _lastCorridorNeonFrame = Duration.zero;
    _corridorNeonCtrl
      ..stop()
      ..reset()
      ..repeat();
  }

  void _stopCorridorNeonLoop() {
    _corridorNeonCtrl
      ..stop()
      ..reset();
    _lastCorridorNeonFrame = Duration.zero;
  }

  // ── Heatmap fade ──────────────────────────────────────────────────────────
  // عند وصول داتا جديدة: نبدأ fade من 0.0 → 1.0، وكل frame نعيد بناء
  // الـ hexagons بالألفا الحالية، فالتحديث بيظهر بنعومة بدل قفزة مفاجئة.
  void _onHeatmapFadeFrame() {
    final v = _heatmapFadeCtrl.value;
    if (v >= 1.0) {
      _heatmapAlpha = 1.0;
    } else {
      // منحنى ease-out ناعم
      _heatmapAlpha = 1.0 - (1.0 - v) * (1.0 - v);
    }
    if (!mounted) return;
    setState(() {});
  }

  void _triggerHeatmapFade(List<HeatmapCell> cells) {
    _renderedHeatmapCells = cells;
    _heatmapFadeCtrl
      ..stop()
      ..reset()
      ..forward();
  }

  Set<Polyline> _buildCorridorNeonPolylines() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final routeColor =
        isDark ? const Color(0xFF34E7FF) : const Color(0xFF4169FF);
    return NeonRoutePolyline.build(
      points: _corridorRoutePoints,
      progress: NeonRoutePolyline.drawProgress(_corridorNeonCtrl.value),
      opacity: NeonRoutePolyline.fadeOpacity(_corridorNeonCtrl.value),
      color: routeColor,
      idPrefix: 'driver_corridor_neon',
      coreWidth: _corridorNeonCoreWidth,
      glowWidth: _corridorNeonGlowWidth,
      haloWidth: _corridorNeonHaloWidth,
    );
  }

  bool get _hasActiveCorridor =>
      _corridorRoutePoints.length >= 2 || _corridorMarkers.isNotEmpty;

  Future<void> _fitCorridorCamera({bool force = false}) async {
    if (_mapController == null || !_hasActiveCorridor) return;
    if (_corridorCameraFitInFlight) return;
    if (_corridorCameraFitted && !force) return;

    final points = _corridorRoutePoints.length >= 2
        ? _corridorRoutePoints
        : _corridorMarkers.map((m) => m.position).toList(growable: false);
    if (points.length < 2) return;

    _corridorCameraFitInFlight = true;
    try {
      await MapCameraUtils.fitCameraToPoints(
        _mapController!,
        points,
        padding: 76,
        delay: const Duration(milliseconds: 180),
      );
      _corridorCameraFitted = true;
    } finally {
      _corridorCameraFitInFlight = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final bloc = context.read<DriverHomeBloc>();

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      bloc.add(DriverAppPaused());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      // Re-check location permission when returning from Settings
      context.read<LocationPermissionCubit>().recheck();

      bloc.add(DriverAppResumed());
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
      AppLogger.warning('DriverHome: animateCamera failed: $e');
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
          if (_hasActiveCorridor) {
            _fitCorridorCamera();
            return;
          }
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
                AppToast.error(msg);
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
          prev.driverLng != curr.driverLng ||
          prev.isAvailable != curr.isAvailable ||
          prev.heatmapCells != curr.heatmapCells,
      builder: (context, state) {
        final markers = <Marker>{..._corridorMarkers};
        // فعّل fade عند وصول داتا heatmap جديدة (مرة واحدة لكل تحديث).
        final cellsChanged = _renderedHeatmapCells.length != state.heatmapCells.length ||
            !identical(_renderedHeatmapCells, state.heatmapCells);
        if (cellsChanged) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => _triggerHeatmapFade(state.heatmapCells));
        }
        final hexagons = _buildHeatmapHexagons(
            _renderedHeatmapCells, _heatmapAlpha);
        final initialCamera =
            (state.driverLat != null && state.driverLng != null)
                ? CameraPosition(
                    target: LatLng(state.driverLat!, state.driverLng!),
                    zoom: 15)
                : _defaultCamera;

        return AppGoogleMap(
          initialCameraPosition: initialCamera,
          onMapCreated: (ctrl) {
            _mapController = ctrl;
            _lastAnimatedLat = null;
            _lastAnimatedLng = null;
            final s = context.read<DriverHomeBloc>().state;
            if (_hasActiveCorridor) {
              Future.microtask(() => _fitCorridorCamera(force: true));
            } else if (s.driverLat != null && s.driverLng != null) {
              Future.microtask(() => _animateTo(s.driverLat!, s.driverLng!));
            }
          },
          myLocationEnabled: true,
          markers: markers,
          polygons: hexagons,
          polylines: _corridorPolylines, // ✅ corridor drawn here
          padding: const EdgeInsets.only(
            bottom: _mapBottomPadding,
            top: _mapTopPadding,
          ),
        );
      },
    );
  }

  static const double _hexRadiusMeters = 300.0;

  Set<Polygon> _buildHeatmapHexagons(List<HeatmapCell> cells, double alpha) {
    return cells.map((cell) {
      Color fillColor;
      Color strokeColor;

      // الألفا بتاعة الـ fade تُضرب في ألفا اللون الأصلي → fade ناعم.
      switch (cell.level) {
        case HeatmapLevel.high:
          fillColor = AppColors.error.withValues(alpha: 0.35 * alpha);
          strokeColor = AppColors.error.withValues(alpha: 0.60 * alpha);
          break;
        case HeatmapLevel.medium:
          fillColor = AppColors.warning.withValues(alpha: 0.25 * alpha);
          strokeColor = AppColors.warning.withValues(alpha: 0.50 * alpha);
          break;
        case HeatmapLevel.low:
          fillColor = AppColors.warningLight.withValues(alpha: 0.16 * alpha);
          strokeColor = AppColors.warningLight.withValues(alpha: 0.35 * alpha);
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
    const latPerMeter = 1.0 / 111320.0;
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
                          PriceFormatter.displayWithCurrency(
                              context, state.availableBalance),
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
      bottom: 120,
      right: 18,
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
        builder: (_) => CorridorPickerScreen(
          initialCenter: LatLng(lat, lng),
        ),
      ),
    ).then((result) {
      if (result == null) return;
      if (result.containsKey('cleared')) {
        // User cleared the corridor
        _stopCorridorNeonLoop();
        if (mounted) {
          setState(() {
            _corridorRoutePoints = [];
            _corridorPolylines = {};
            _corridorMarkers = {};
            _corridorCameraFitted = false;
          });
        }
        return;
      }
      final origin = result['origin']!;
      final dest = result['dest']!;
      _drawCorridorPolyline(origin, dest);
    });
  }

  Future<void> _drawCorridorPolyline(LatLng origin, LatLng dest) async {
    if (!mounted) return;
    final l = AppLocalizations.of(context)!;

    // Show markers immediately
    _stopCorridorNeonLoop();
    setState(() {
      _corridorRoutePoints = [];
      _corridorPolylines = {};
      _corridorCameraFitted = false;
      _corridorMarkers = {
        Marker(
          markerId: const MarkerId('corr_origin'),
          position: origin,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(title: l.corridorStart),
        ),
        Marker(
          markerId: const MarkerId('corr_dest'),
          position: dest,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(title: l.corridorEnd),
        ),
      };
    });
    await _fitCorridorCamera(force: true);

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
      _corridorRoutePoints = points;
      _corridorPolylines = _buildCorridorNeonPolylines();
      _corridorCameraFitted = false;
    });
    _restartCorridorNeonLoop();

    // Fit camera to polyline
    await _fitCorridorCamera(force: true);
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
      onBonusTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.driverBonus);
      },
      onRevisionTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.driverRevision);
      },
      onPrivacyTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.privacyPolicy);
      },
      onHelpTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.helpSupport);
      },
      onLogout: () {
        Navigator.pop(context);
        context.read<DriverHomeBloc>().add(ResetDriverStatus());
        context.read<AuthBloc>().add(SignOutRequested());
      },
    );
  }
}
