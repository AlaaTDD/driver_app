
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

  
  static const double _bottomSheetHeight = 236.0;
  static const double _mapButtonSize = 48.0;
  static const double _mapButtonRadius = 14.0;
  static const double _topBarHorizontalPadding = 18.0;
  static const double _topBarVerticalPadding = 14.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check location permission on init
    context.read<LocationPermissionCubit>().check();
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
                prev.acceptedTripId != curr.acceptedTripId && curr.acceptedTripId != null,
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
                prev.errorMessage != curr.errorMessage && curr.errorMessage != null,
            listener: (context, state) {
              if (state.errorMessage != null && state.errorMessage!.isNotEmpty) {
                final l = AppLocalizations.of(context)!;
                final msg = switch (state.errorMessage) {
                  'errorCannotGoOnlineDuringTrip' => l.errorCannotGoOnlineDuringTrip,
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
        final markers = <Marker>{};
        
        // Removed the red marker pin as requested
        

        
        final hexagons = _buildHeatmapHexagons(state.heatmapCells);

        
        
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
            _mapController = ctrl;

            
            _lastAnimatedLat = null;
            _lastAnimatedLng = null;

            
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: context.elevatedColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.priceWithCurrency(state.availableBalance.toStringAsFixed(0), AppLocalizations.of(context)!.egp),
                          style: TextStyle(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right_rounded, color: context.textSecondary, size: 16),
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
    return CustomAnimatedBottomNav(
      items: const [
        BottomNavItem(
          icon: Icons.list_alt_outlined,
          activeIcon: Icons.list_alt_rounded,
          label: 'الرحلات',
        ),
        BottomNavItem(
          icon: Icons.alt_route_outlined,
          activeIcon: Icons.alt_route_rounded,
          label: 'الوجهة',
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
      notchColor: Colors.transparent,
      notchRadius: 42,
      gapWidth: 90,
      floatingActionButton: _buildGoButtonInner(),
    );
  }

  void _showCorridorPicker(BuildContext context) {
    final bloc = context.read<DriverHomeBloc>();
    final lat  = bloc.state.driverLat ?? AppConstants.defaultMapCenter.latitude;
    final lng  = bloc.state.driverLng ?? AppConstants.defaultMapCenter.longitude;
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CorridorPickerScreen(
          driverLocation: LatLng(lat, lng),
        ),
      ),
    );
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
                                const Color(0xFF10B981), 
                                const Color(0xFF047857), 
                              ]
                            : [
                                const Color(0xFFEF4444), 
                                const Color(0xFFB91C1C), 
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isOnline ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                              .withValues(alpha: 0.5),
                          blurRadius: isOnline ? 25 : 15,
                          spreadRadius: isOnline ? 8 : 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 3)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isOnline ? Icons.sensors_rounded : Icons.power_settings_new_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isOnline ? AppLocalizations.of(context)!.onlineStatus : AppLocalizations.of(context)!.offlineStatus,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
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
//  CORRIDOR PICKER SCREEN (replaces _TargetRouteDialog)
// ═══════════════════════════════════════════════════════════════════════════

class _CorridorPickerScreen extends StatefulWidget {
  final LatLng driverLocation;
  const _CorridorPickerScreen({required this.driverLocation});

  @override
  State<_CorridorPickerScreen> createState() => _CorridorPickerScreenState();
}

class _CorridorPickerScreenState extends State<_CorridorPickerScreen> {
  LatLng? _destPoint;
  String? _destAddress;
  double _destRadiusKm  = 3.0;
  double _originRadiusKm = 2.0;
  bool _isResolving = false;
  bool _isSaving    = false;

  Future<void> _onMapTap(LatLng ll) async {
    setState(() { _destPoint = ll; _isResolving = true; _destAddress = null; });
    try {
      final placemarks = await placemarkFromCoordinates(ll.latitude, ll.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() => _destAddress = '${p.street ?? ''}, ${p.locality ?? ''}');
      }
    } catch (_) {
      setState(() => _destAddress =
          '${ll.latitude.toStringAsFixed(4)}, ${ll.longitude.toStringAsFixed(4)}');
    } finally {
      setState(() => _isResolving = false);
    }
  }

  Future<void> _save() async {
    if (_destPoint == null) return;
    setState(() => _isSaving = true);
    try {
      await SupabaseService.client.rpc('set_driver_target_route', params: {
        'p_lat': _destPoint!.latitude,
        'p_lng': _destPoint!.longitude,
        'p_address': _destAddress ?? '',
        'p_active': true,
      });
      // Also update the 4 corridor columns directly (RPC may not have them yet)
      await SupabaseService.client
          .from('drivers_profile')
          .update({
            'target_origin_lat'      : widget.driverLocation.latitude,
            'target_origin_lng'      : widget.driverLocation.longitude,
            'target_origin_radius_km': _originRadiusKm,
            'target_route_radius_km' : _destRadiusKm,
          })
          .eq('id', SupabaseService.currentUser!.id);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديد الممر المفضل: $_destAddress'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clear() async {
    try {
      await SupabaseService.client.rpc('set_driver_target_route', params: {
        'p_lat': null, 'p_lng': null, 'p_address': null, 'p_active': false,
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء الممر المفضل')),
        );
      }
    } catch (e) {
      debugPrint('CorridorPicker: clear failed $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF12151F) : Colors.white,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: Colors.white70),
          ),
        ),
        actions: [
          GestureDetector(
            onTap: _clear,
            child: Container(
              margin: const EdgeInsets.only(right: 12, top: 10, bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.shade900.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text('إلغاء الممر', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: Stack(children: [
        // ── Map ───────────────────────────────────────────────────────────
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: widget.driverLocation,
            zoom: 13,
          ),
          onTap: _onMapTap,
          style: isDark ? kDarkMapStyle : kLightMapStyle,
          myLocationEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          circles: {
            // Origin zone — fixed at driver current position
            Circle(
              circleId: const CircleId('origin_zone'),
              center: widget.driverLocation,
              radius: _originRadiusKm * 1000,
              fillColor: Colors.green.withValues(alpha: 0.12),
              strokeColor: Colors.green.withValues(alpha: 0.7),
              strokeWidth: 2,
            ),
            // Destination zone — user taps to place
            if (_destPoint != null)
              Circle(
                circleId: const CircleId('dest_zone'),
                center: _destPoint!,
                radius: _destRadiusKm * 1000,
                fillColor: Colors.blue.withValues(alpha: 0.12),
                strokeColor: Colors.blue.withValues(alpha: 0.7),
                strokeWidth: 2,
              ),
          },
          polylines: _destPoint != null ? {
            Polyline(
              polylineId: const PolylineId('corridor_line'),
              points: [widget.driverLocation, _destPoint!],
              color: Colors.blue.withValues(alpha: 0.55),
              width: 3,
              patterns: [PatternItem.dash(20), PatternItem.gap(10)],
            ),
          } : {},
          markers: {
            Marker(
              markerId: const MarkerId('origin'),
              position: widget.driverLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'موقعك الحالي'),
            ),
            if (_destPoint != null)
              Marker(
                markerId: const MarkerId('dest'),
                position: _destPoint!,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                infoWindow: InfoWindow(title: _destAddress ?? 'الوجهة المستهدفة'),
              ),
          },
        ),

        // ── Hint overlay (tap to select) ──────────────────────────────────
        if (_destPoint == null)
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.touch_app_rounded, color: Colors.white70, size: 18),
                  SizedBox(width: 8),
                  Text('اضغط على الخريطة لتحديد الوجهة المستهدفة',
                      style: TextStyle(color: Colors.white, fontSize: 13)),
                ]),
              ),
            ),
          ),

        // ── Bottom controls panel ─────────────────────────────────────────
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1526) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20, offset: Offset(0, -4))],
            ),
            padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Drag handle
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(100)))),
              const SizedBox(height: 16),

              // Title + selected address
              Row(children: [
                Container(width: 40, height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.alt_route_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('تحديد الممر المفضل',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  Text(
                    _isResolving ? 'جاري التحليل...' :
                    _destAddress ?? (_destPoint == null ? 'لم يتم التحديد بعد' : 'تم التحديد'),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ])),
              ]),

              const SizedBox(height: 20),

              // Origin radius slider (green)
              _RadiusSlider(
                label: 'نطاق نقطة الانطلاق',
                color: Colors.green,
                value: _originRadiusKm,
                min: 0.5, max: 10.0,
                onChanged: (v) => setState(() => _originRadiusKm = v),
              ),
              const SizedBox(height: 12),

              // Destination radius slider (blue) — enabled only when dest chosen
              _RadiusSlider(
                label: 'نطاق الوجهة',
                color: Colors.blue,
                value: _destRadiusKm,
                min: 0.5, max: 15.0,
                enabled: _destPoint != null,
                onChanged: (v) => setState(() => _destRadiusKm = v),
              ),
              const SizedBox(height: 20),

              // Legend chips
              Row(children: [
                _LegendChip(color: Colors.green, label: 'منطقة الانطلاق'),
                const SizedBox(width: 10),
                _LegendChip(color: Colors.blue, label: 'منطقة الوصول'),
              ]),
              const SizedBox(height: 20),

              // Save button
              SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: (_isSaving || _destPoint == null || _isResolving) ? null : _save,
                  icon: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded),
                  label: Text(_destPoint == null ? 'اختر وجهة أولاً' : 'حفظ الممر المفضل'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade800,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
        width: 120,
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: enabled ? null : Colors.grey)),
      ),
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: enabled ? color : Colors.grey.shade700,
            inactiveTrackColor: Colors.grey.withValues(alpha: 0.2),
            thumbColor: enabled ? color : Colors.grey,
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
            style: TextStyle(fontSize: 11, color: enabled ? color : Colors.grey,
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
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 12,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.3), shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5))),
    const SizedBox(width: 6),
    Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  ]);
}
