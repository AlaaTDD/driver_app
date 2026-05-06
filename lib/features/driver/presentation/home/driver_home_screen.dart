
import 'dart:async';
import 'package:snapix/core/localization/generated/app_localizations.dart';
import 'dart:io' show Platform;
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
            backgroundColor: context.bgColor,
            drawer: _buildDrawer(context),
            body: Stack(
              children: [
                _buildMap(),
                _buildTopBar(),
                _buildLocationButton(),
                _buildGoButton(),
              ],
            ),
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
            
            
            _mapController?.dispose();
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
      bottom: 40,
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

  

  Widget _buildGoButton() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: BlocBuilder<DriverHomeBloc, DriverHomeState>(
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
                width: 75,
                height: 75,
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
        ),
      ),
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


