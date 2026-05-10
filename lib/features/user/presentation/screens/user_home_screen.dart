import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/map_styles.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/bottom_sheet_container.dart';
import '../../../../core/widgets/map_button.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../services/cell_subscription_service.dart';
import '../home/bloc/user_home_bloc.dart';
import '../home/bloc/user_home_event.dart';
import '../home/bloc/user_home_state.dart';
import '../../../../core/localization/generated/app_localizations.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  GoogleMapController? _mapController;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  LatLng? _initialPosition;
  bool _isLocating = true;

  double? _lastAnimatedLat;
  double? _lastAnimatedLng;

  bool _initialized = false;
  final Map<String, LatLng> _targetDriverPositions = {};
  final Map<String, LatLng> _animatedDriverPositions = {};
  final Map<String, double> _driverRotations = {};
  final ValueNotifier<Set<Marker>> _markersNotifier = ValueNotifier({});
  Ticker? _animationTicker;

  BitmapDescriptor? _carIcon;

  static const double _bottomSheetHeight = 236;
  static const double _mapButtonSize = 48.0;
  static const double _mapButtonRadius = 14.0;
  static const double _topBarHorizontalPadding = 18.0;
  static const double _topBarVerticalPadding = 14.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCarIcon();
    _startAnimationLoop();
  }

  void _startAnimationLoop() {
    _animationTicker?.dispose();
    _animationTicker = createTicker((_) {
      bool needsUpdate = false;
      for (final id in _targetDriverPositions.keys) {
        final prev = _animatedDriverPositions[id] ?? _targetDriverPositions[id]!;
        final target = _targetDriverPositions[id]!;

        if (prev.latitude != target.latitude || prev.longitude != target.longitude) {
          final newLat = prev.latitude + (target.latitude - prev.latitude) * 0.1;
          final newLng = prev.longitude + (target.longitude - prev.longitude) * 0.1;

          if ((newLat - target.latitude).abs() < 0.00001 &&
              (newLng - target.longitude).abs() < 0.00001) {
            _animatedDriverPositions[id] = target;
          } else {
            _animatedDriverPositions[id] = LatLng(newLat, newLng);
          }
          needsUpdate = true;
        }
      }
      if (needsUpdate && mounted) {
        _markersNotifier.value = _buildDriverMarkers();
      }
    });
    _animationTicker?.start();
  }

  double _calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lng1 = start.longitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final lng2 = end.longitude * math.pi / 180;

    final dLng = lng2 - lng1;
    final y = math.sin(dLng) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLng);

    double bearing = math.atan2(y, x) * 180 / math.pi;
    return (bearing + 360) % 360;
  }

  void _updateDriverPositions(Map<String, DriverLocation> drivers) {
    // Remove old drivers
    final currentIds = drivers.keys.toSet();
    _targetDriverPositions.removeWhere((key, value) => !currentIds.contains(key));
    _animatedDriverPositions.removeWhere((key, value) => !currentIds.contains(key));
    _driverRotations.removeWhere((key, value) => !currentIds.contains(key));

    for (final d in drivers.values) {
      final id = d.driverId;
      final newLoc = LatLng(d.lat, d.lng);

      final currentTarget = _targetDriverPositions[id];
      if (currentTarget == null) {
        _animatedDriverPositions[id] = newLoc;
        _targetDriverPositions[id] = newLoc;
        _driverRotations[id] = 0.0;
      } else if (currentTarget.latitude != newLoc.latitude || currentTarget.longitude != newLoc.longitude) {
        final bearing = _calculateBearing(currentTarget, newLoc);
        if ((currentTarget.latitude - newLoc.latitude).abs() > 0.00001 || 
            (currentTarget.longitude - newLoc.longitude).abs() > 0.00001) {
          _driverRotations[id] = bearing;
        }
        _targetDriverPositions[id] = newLoc;
      }
    }
    
    if (mounted) {
      _markersNotifier.value = _buildDriverMarkers();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialized) {
      _initialized = true;
      _loadLocationThenInit();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationTicker?.dispose();
    _markersNotifier.dispose();
    _mapController?.dispose();
    _mapController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final bloc = context.read<UserHomeBloc>();
      if (bloc.state is UserHomeLoaded) {
        final loaded = bloc.state as UserHomeLoaded;

        _lastAnimatedLat = null;
        _lastAnimatedLng = null;
        _animateTo(loaded.userLat, loaded.userLng);
        
        // Force a refresh of the websocket and initial drivers to fix "getting stuck"
        CellSubscriptionService.instance.refresh();
      }
    }
  }

  Future<void> _loadCarIcon() async {
    try {
      final data = await rootBundle.load('assets/images/carr.png');
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: 40);
      final frame = await codec.getNextFrame();
      final resizedBytes =
          await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (resizedBytes != null && mounted) {
        setState(() {
          _carIcon = BitmapDescriptor.bytes(resizedBytes.buffer.asUint8List());
        });
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load car icon: $e');
      if (mounted) {
        setState(() {
          _carIcon =
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
        });
      }
    }
  }

  Future<void> _loadLocationThenInit() async {
    try {
      final bloc = context.read<UserHomeBloc>();

      if (bloc.state is UserHomeLoaded) {
        final loaded = bloc.state as UserHomeLoaded;
        if (mounted) {
          setState(() {
            _initialPosition = LatLng(loaded.userLat, loaded.userLng);
            _isLocating = false;
          });
          _updateDriverPositions(loaded.nearbyDrivers);
        }
        debugPrint('📍 UserHome: Already loaded — skipping re-init');
        return;
      }

      final authState = context.read<AuthBloc>().state;
      if (authState is! AuthAuthenticated) return;

      bloc.add(InitUserHome(authState.user.id));

      try {
        final loadedState = await bloc.stream
            .firstWhere((s) => s is UserHomeLoaded || s is UserHomeError)
            .timeout(const Duration(seconds: 5));
        if (!mounted) return;
        if (loadedState is UserHomeLoaded) {
          setState(() {
            _initialPosition = LatLng(loadedState.userLat, loadedState.userLng);
            _isLocating = false;
          });
          _updateDriverPositions(loadedState.nearbyDrivers);
        } else {
          setState(() {
            _initialPosition = AppConstants.defaultMapCenter;
            _isLocating = false;
          });
        }
      } catch (e) {
        debugPrint('⚠️ UserHomeScreen: Location timeout: $e');

        if (mounted) {
          setState(() {
            _initialPosition = AppConstants.defaultMapCenter;
            _isLocating = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ UserHomeScreen: Failed to load initial location — $e');
      if (mounted) {
        setState(() {
          _initialPosition = AppConstants.defaultMapCenter;
          _isLocating = false;
        });
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
      debugPrint('⚠️ UserHome: animateCamera failed: $e');
    }
  }

  Set<Marker> _buildDriverMarkers() {
    final icon = _carIcon ??
        BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    return _animatedDriverPositions.entries.map((entry) {
      final id = entry.key;
      final pos = entry.value;
      final rotation = _driverRotations[id] ?? 0.0;

      return Marker(
        markerId: MarkerId('driver_$id'),
        position: pos,
        icon: icon,
        rotation: rotation,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        zIndexInt: 2,
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLocating || _initialPosition == null) {
      return _buildLocatingScreen();
    }

    return BlocListener<UserHomeBloc, UserHomeState>(
      listenWhen: (prev, curr) => prev != curr,
      listener: (context, state) {
        if (state is UserHomeLoaded) {
          _animateTo(state.userLat, state.userLng);
          _updateDriverPositions(state.nearbyDrivers);
        } else if (state is UserHomeError) {
          AppToast.error(ErrorMapper.getErrorMessage(context, state.message));
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
            _buildBottomSheet(),
          ],
        ),
      ),
    );
  }

  Widget _buildLocatingScreen() {
    return Scaffold(
      backgroundColor: context.bgColor,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.locating,
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                letterSpacing: 0.2,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMap() {
    return ValueListenableBuilder<Set<Marker>>(
      valueListenable: _markersNotifier,
      builder: (context, markers, child) {
        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: _initialPosition!,
            zoom: 15,
          ),
          onMapCreated: (ctrl) {
            _mapController?.dispose();
            _mapController = ctrl;

            _lastAnimatedLat = null;
            _lastAnimatedLng = null;

            final s = context.read<UserHomeBloc>().state;
            if (s is UserHomeLoaded) {
              Future.microtask(() => _animateTo(s.userLat, s.userLng));
            }
          },
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapType: MapType.normal,
          markers: markers,
          padding: const EdgeInsets.only(bottom: _bottomSheetHeight + 8),
          style: Theme.of(context).brightness == Brightness.dark
              ? kDarkMapStyle
              : kLightMapStyle,
        );
      },
    );
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
            MapButton(
              icon: Icons.notifications_outlined,
              size: _mapButtonSize,
              borderRadius: _mapButtonRadius,
              onTap: () => context.push(AppRoutes.userNotifications),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationButton() {
    return Positioned(
      bottom: _bottomSheetHeight + 16,
      right: 18,
      child: MapButton(
        icon: Icons.my_location_rounded,
        size: _mapButtonSize,
        borderRadius: _mapButtonRadius,
        onTap: () {
          final state = context.read<UserHomeBloc>().state;
          if (state is UserHomeLoaded) {
            _lastAnimatedLat = null;
            _lastAnimatedLng = null;
            _animateTo(state.userLat, state.userLng);
          }
        },
      ),
    );
  }

  Widget _buildBottomSheet() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: BottomSheetContainer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.whereToGo,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                letterSpacing: -0.3,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 14),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push(AppRoutes.userLocationSelect),
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: context.elevatedColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.divColor, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color: context.textSecondary,
                      size: 21,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      AppLocalizations.of(context)!.searchDestination,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            BlocBuilder<UserHomeBloc, UserHomeState>(
              builder: (context, state) {
                if (state is UserHomeLoaded && state.coupons.isNotEmpty) {
                  final userCoupon = state.coupons.first;
                  final coupon = userCoupon['coupons'] as Map<String, dynamic>?;
                  if (coupon != null) {
                    return _CouponBanner(
                      code: coupon['code']?.toString() ?? '',
                      discount: coupon['discount_value']?.toString() ?? '',
                    );
                  }
                }
                return const _PromoBanner();
              },
            ),
          ],
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
        context.push(AppRoutes.userProfile);
      },
      onTripsTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.userTrips);
      },
      onMessagesTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.userMessages);
      },
      onWalletTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.userWallet);
      },
      onChatbotTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.userChatbot);
      },
      onComplaintsTap: () {
        Navigator.pop(context);
        context.push(AppRoutes.userComplaints);
      },
      onLogout: () {
        Navigator.pop(context);
        context.read<AuthBloc>().add(SignOutRequested());
      },
    );
  }
}

class _CouponBanner extends StatelessWidget {
  final String code;
  final String discount;

  const _CouponBanner({required this.code, required this.discount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.primaryTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary, width: 0.8),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_offer_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.haveCoupon,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!
                      .discountWithCode(discount, code),
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 20),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divColor, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: context.primaryTint,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.local_taxi_rounded,
              color: AppColors.primary,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.rideSafely,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  AppLocalizations.of(context)!.bookNowEnjoy,
                  style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 11,
                    height: 1.4,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
