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
import '../../../../core/errors/error_mapper.dart';
import '../../../../core/widgets/app_drawer.dart';
import '../../../../core/widgets/bottom_sheet_container.dart';
import '../../../../core/widgets/map_button.dart';
import '../../../../core/widgets/location_permission_cta.dart';
import '../../../../core/bloc/location_permission_cubit.dart';
import '../../../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../../../features/auth/presentation/bloc/auth_event.dart';
import '../../../../features/auth/presentation/bloc/auth_state.dart';
import '../../../../services/cell_subscription_service.dart';
import '../../../../services/supabase_service.dart';
import '../../data/repositories/coupon_repository.dart';
import '../location_selection/location_selection_args.dart';
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

  static const double _compactBottomSheetHeight = 236;
  static const double _couponBottomSheetHeight = 348;
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
    // Check location permission on init
    context.read<LocationPermissionCubit>().check();
  }

  void _startAnimationLoop() {
    _animationTicker?.dispose();
    _animationTicker = createTicker((_) {
      bool needsUpdate = false;
      for (final id in _targetDriverPositions.keys) {
        final prev =
            _animatedDriverPositions[id] ?? _targetDriverPositions[id]!;
        final target = _targetDriverPositions[id]!;

        if (prev.latitude != target.latitude ||
            prev.longitude != target.longitude) {
          final newLat =
              prev.latitude + (target.latitude - prev.latitude) * 0.1;
          final newLng =
              prev.longitude + (target.longitude - prev.longitude) * 0.1;

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
    _targetDriverPositions
        .removeWhere((key, value) => !currentIds.contains(key));
    _animatedDriverPositions
        .removeWhere((key, value) => !currentIds.contains(key));
    _driverRotations.removeWhere((key, value) => !currentIds.contains(key));

    for (final d in drivers.values) {
      final id = d.driverId;
      final newLoc = LatLng(d.lat, d.lng);

      final currentTarget = _targetDriverPositions[id];
      if (currentTarget == null) {
        _animatedDriverPositions[id] = newLoc;
        _targetDriverPositions[id] = newLoc;
        _driverRotations[id] = 0.0;
      } else if (currentTarget.latitude != newLoc.latitude ||
          currentTarget.longitude != newLoc.longitude) {
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
      // Re-check location permission when returning from Settings
      context.read<LocationPermissionCubit>().recheck();

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

  static bool _hasDisplayCoupon(UserHomeState state) {
    return state is UserHomeLoaded &&
        state.coupons.any((row) => row['coupons'] is Map<String, dynamic>);
  }

  static double _sheetHeightForState(UserHomeState state) {
    return _hasDisplayCoupon(state)
        ? _couponBottomSheetHeight
        : _compactBottomSheetHeight;
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
            const SizedBox(
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
    return BlocBuilder<UserHomeBloc, UserHomeState>(
      buildWhen: (prev, curr) =>
          _hasDisplayCoupon(prev) != _hasDisplayCoupon(curr),
      builder: (context, homeState) {
        final sheetHeight = _sheetHeightForState(homeState);
        return ValueListenableBuilder<Set<Marker>>(
          valueListenable: _markersNotifier,
          builder: (context, markers, child) {
            return GoogleMap(
              key: const ValueKey('user_home_map'),
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
              padding: EdgeInsets.only(bottom: sheetHeight + 8),
              style: Theme.of(context).brightness == Brightness.dark
                  ? kDarkMapStyle
                  : kLightMapStyle,
            );
          },
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
    return BlocBuilder<UserHomeBloc, UserHomeState>(
      buildWhen: (prev, curr) =>
          _hasDisplayCoupon(prev) != _hasDisplayCoupon(curr),
      builder: (context, state) {
        return Positioned(
          bottom: _sheetHeightForState(state) + 16,
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
      },
    );
  }

  Widget _buildBottomSheet() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: BottomSheetContainer(
        child: BlocBuilder<LocationPermissionCubit, LocationPermissionState>(
          builder: (context, permState) {
            // ── Location blocked → show CTA instead of search ──
            if (permState.isBlocked) {
              return Column(
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
                  LocationPermissionCta(
                    variant: LocationCtaVariant.card,
                    onGranted: () {
                      // Re-init location when granted
                      final authState = context.read<AuthBloc>().state;
                      if (authState is AuthAuthenticated) {
                        context
                            .read<UserHomeBloc>()
                            .add(InitUserHome(authState.user.id));
                      }
                    },
                  ),
                ],
              );
            }

            // ── Normal state → search bar + promo ──
            return Column(
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
                const SizedBox(height: 10),
                BlocBuilder<UserHomeBloc, UserHomeState>(
                  builder: (context, state) {
                    if (state is UserHomeLoaded && state.coupons.isNotEmpty) {
                      final userCoupon = state.coupons.first;
                      final coupon =
                          userCoupon['coupons'] as Map<String, dynamic>?;
                      if (coupon != null) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _CouponBanner(coupon: coupon),
                          ],
                        );
                      }
                    }
                    return const _PromoBanner();
                  },
                ),
              ],
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

class _CouponBanner extends StatefulWidget {
  final Map<String, dynamic> coupon;
  const _CouponBanner({required this.coupon});

  @override
  State<_CouponBanner> createState() => _CouponBannerState();
}

class _CouponBannerState extends State<_CouponBanner> {
  Timer? _copyTimer;
  bool _copied = false;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _copyCode(String code, AppLocalizations l) async {
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _copied = true);
    AppToast.success(l.couponCodeCopied);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final textDirection = Directionality.of(context);
    final String code = widget.coupon['code']?.toString() ?? '';
    final num discountVal = (widget.coupon['discount_value'] as num?) ?? 0;
    final String discountType =
        widget.coupon['discount_type']?.toString() ?? 'percentage';

    final bool isPercent = discountType == 'percentage';
    final String discountNumber = isPercent
        ? '${discountVal.toStringAsFixed(0)}%'
        : discountVal.toStringAsFixed(0);

    final bool isDark = context.isDark;
    final cardColor = isDark ? const Color(0xFF151A2B) : AppColors.white;
    final cardBorder =
        isDark ? const Color(0xFF28324A) : const Color(0xFFE8EDF5);
    final titleColor = isDark ? AppColors.white : const Color(0xFF111827);
    final subtitleColor =
        isDark ? const Color(0xFFA5AEC3) : const Color(0xFF6B7280);
    final mutedColor =
        isDark ? const Color(0xFF8D96AB) : const Color(0xFF6B7280);
    final codeBorder = isDark
        ? const Color(0xFF6863FF).withValues(alpha: 0.58)
        : const Color(0xFF8F85E8).withValues(alpha: 0.54);
    final codeTextColor =
        isDark ? const Color(0xFF817BFF) : const Color(0xFF4B55D9);
    final codeFill = isDark ? const Color(0xFF11162A) : const Color(0xFFFBFBFF);
    final dividerColor =
        isDark ? const Color(0xFF262D42) : const Color(0xFFE9EDF4);
    final badgeBg = isDark ? const Color(0xFF3A2C14) : const Color(0xFFFFF1D6);
    final badgeText =
        isDark ? const Color(0xFFFFB545) : const Color(0xFFE69A00);
    final ticketGradient = isDark
        ? const [Color(0xFFB86B00), Color(0xFFD48A00)]
        : const [Color(0xFFFFC329), Color(0xFFFF9F0A)];
    final buttonGradient = isDark
        ? const [Color(0xFF6E63FF), Color(0xFF463CE8)]
        : const [Color(0xFF5C54F5), Color(0xFF4238DD)];

    void openLocationSelection() {
      context.push(
        AppRoutes.userLocationSelect,
        extra: LocationSelectionArgs(
          initialCouponCode: code,
          initialCouponDiscount: discountVal.toDouble(),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - value)),
          child: child,
        ),
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cardBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: isDark ? 0.34 : 0.10),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: AppColors.black.withValues(alpha: isDark ? 0.18 : 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Text(
                                l.discountLimited,
                                textDirection: textDirection,
                                style: TextStyle(
                                  color: badgeText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l.discountOnYourRide,
                                textAlign: TextAlign.center,
                                textDirection: textDirection,
                                maxLines: 1,
                                style: TextStyle(
                                  color: titleColor,
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(
                            width: double.infinity,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                l.useCodeForInstantDiscount,
                                textAlign: TextAlign.center,
                                textDirection: textDirection,
                                maxLines: 1,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          CustomPaint(
                            painter: _DashedBorderPainter(
                              color: codeBorder,
                              borderRadius: 12,
                              strokeWidth: 1.25,
                              dashWidth: 6,
                              dashGap: 5,
                            ),
                            child: Material(
                              color: codeFill,
                              borderRadius: BorderRadius.circular(12),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () => _copyCode(code, l),
                                child: SizedBox(
                                  height: 38,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                    ),
                                    child: Row(
                                      textDirection: TextDirection.ltr,
                                      children: [
                                        Tooltip(
                                          message: l.copyCouponCode,
                                          child: Icon(
                                            _copied
                                                ? Icons.check_circle_rounded
                                                : Icons.copy_rounded,
                                            size: 20,
                                            color: _copied
                                                ? AppColors.success
                                                : codeTextColor,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                code,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: codeTextColor,
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 5,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 32),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ClipPath(
                      clipper: const _CouponTicketClipper(),
                      child: Container(
                        width: 86,
                        height: 92,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: ticketGradient,
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              l.discount,
                              textDirection: textDirection,
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                discountNumber,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 31,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                l.discountOnAllTrips,
                                textAlign: TextAlign.center,
                                textDirection: textDirection,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Divider(height: 1, thickness: 1, color: dividerColor),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: AppColors.success,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'سفرك محمي وآمن مع كل رحلة',
                            textDirection: TextDirection.rtl,
                            maxLines: 1,
                            style: TextStyle(
                              color: mutedColor,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: openLocationSelection,
                      child: Container(
                        height: 38,
                        width: 116,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: buttonGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(13),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF5147F7)
                                  .withValues(alpha: 0.24),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.chevron_left_rounded,
                              color: AppColors.white,
                              size: 21,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                AppLocalizations.of(context)!.bookNow,
                                textDirection: textDirection,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CouponTicketClipper extends CustomClipper<Path> {
  static const double _borderRadius = 16;
  static const double _notchRadius = 8;

  const _CouponTicketClipper();

  @override
  Path getClip(Size size) {
    final ticket = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(_borderRadius),
        ),
      );
    final notches = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(0, size.height * 0.5),
          radius: _notchRadius,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, size.height * 0.5),
          radius: _notchRadius,
        ),
      );
    return Path.combine(ui.PathOperation.difference, ticket, notches);
  }

  @override
  bool shouldReclip(covariant _CouponTicketClipper oldClipper) => false;
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double borderRadius;
  final double strokeWidth;
  final double dashWidth;
  final double dashGap;

  _DashedBorderPainter(
      {required this.color,
      this.borderRadius = 10,
      this.strokeWidth = 1.2,
      this.dashWidth = 5,
      this.dashGap = 4});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius));
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter old) =>
      color != old.color ||
      borderRadius != old.borderRadius ||
      strokeWidth != old.strokeWidth ||
      dashWidth != old.dashWidth ||
      dashGap != old.dashGap;
}

class _PromoBanner extends StatefulWidget {
  const _PromoBanner();

  @override
  State<_PromoBanner> createState() => _PromoBannerState();
}

class _PromoBannerState extends State<_PromoBanner> {
  bool _showCouponInput = false;
  final _codeController = TextEditingController();

  // Validation state
  bool _isValidating = false;
  bool? _isValid; // null = not checked, true = valid, false = invalid
  String? _validatedCode;
  double? _validatedDiscount;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _toggleCouponInput() {
    setState(() {
      _showCouponInput = !_showCouponInput;
      if (!_showCouponInput) {
        // Reset validation state when closing
        _isValid = null;
        _errorMessage = null;
      }
    });
  }

  Future<void> _validateAndApply() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;

    setState(() {
      _isValidating = true;
      _isValid = null;
      _errorMessage = null;
    });

    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        setState(() {
          _isValidating = false;
          _isValid = false;
          _errorMessage = AppLocalizations.of(context)!.errorApplyCoupon;
        });
        return;
      }

      final repo = CouponRepository();
      // Validate against a reasonable trip price to check basic validity
      final result = await repo.validateCoupon(
        couponCode: code,
        originalPrice: 100, // Dummy price for validation check
        userId: userId,
      );

      if (!mounted) return;

      if (result.isSuccess) {
        setState(() {
          _isValidating = false;
          _isValid = true;
          _validatedCode = result.couponCode;
          _validatedDiscount = result.discount;
        });
      } else {
        setState(() {
          _isValidating = false;
          _isValid = false;
          _errorMessage = _mapErrorKey(result.errorKey);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isValidating = false;
        _isValid = false;
        _errorMessage = AppLocalizations.of(context)!.errorApplyCoupon;
      });
    }
  }

  String _mapErrorKey(String? key) {
    final l = AppLocalizations.of(context)!;
    return switch (key) {
      'errorInvalidCoupon' => l.errorInvalidCoupon,
      'errorCouponDepleted' => l.errorCouponDepleted,
      'errorCouponUsed' => l.errorCouponUsed,
      'errorApplyCoupon' => l.errorApplyCoupon,
      _ => l.invalidCouponCode,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main promo / coupon toggle banner
        GestureDetector(
          onTap: _toggleCouponInput,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: _showCouponInput
                  ? AppColors.primary.withValues(alpha: 0.06)
                  : context.elevatedColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _showCouponInput
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : context.divColor,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _showCouponInput
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : context.primaryTint,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _showCouponInput
                        ? Icons.local_offer_rounded
                        : Icons.local_taxi_rounded,
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
                        _showCouponInput
                            ? AppLocalizations.of(context)!.haveDiscountCoupon
                            : AppLocalizations.of(context)!.rideSafely,
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
                        _showCouponInput
                            ? AppLocalizations.of(context)!.enterDiscountCode
                            : AppLocalizations.of(context)!.bookNowEnjoy,
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
                AnimatedRotation(
                  turns: _showCouponInput ? 0.25 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    _showCouponInput
                        ? Icons.close_rounded
                        : Icons.confirmation_number_outlined,
                    color: _showCouponInput
                        ? context.textSecondary
                        : AppColors.primary,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Expandable coupon input ──────────────────────────────────────
        // NO AnimatedSize / AnimatedCrossFade / SizeTransition here.
        // All of them internally use AnimatedSize which puts children in an
        // unconstrained Stack — this gives ElevatedButton infinite width and
        // crashes layout. A plain `if` is the only safe pattern in a BottomSheet.
        if (_showCouponInput)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.elevatedColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.divColor, width: 1),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: TextField(
                            controller: _codeController,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (_) {
                              if (_isValid != null) {
                                setState(() {
                                  _isValid = null;
                                  _errorMessage = null;
                                });
                              }
                            },
                            style: TextStyle(
                              color: context.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.5,
                            ),
                            decoration: InputDecoration(
                              hintText: 'PROMO20',
                              hintStyle: TextStyle(
                                color: context.textSecondary
                                    .withValues(alpha: 0.4),
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                letterSpacing: 1.5,
                              ),
                              filled: true,
                              fillColor: context.bgColor,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: _isValid == true
                                        ? AppColors.success
                                            .withValues(alpha: 0.5)
                                        : _isValid == false
                                            ? AppColors.error
                                                .withValues(alpha: 0.5)
                                            : context.divColor,
                                    width: _isValid != null ? 1.5 : 0.8),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: BorderSide(
                                    color: AppColors.primary, width: 1.2),
                              ),
                              prefixIcon: Icon(Icons.local_offer_rounded,
                                  color: _isValid == true
                                      ? AppColors.success
                                      : _isValid == false
                                          ? AppColors.error
                                          : context.textSecondary,
                                  size: 16),
                              suffixIcon: _isValid == true
                                  ? const Icon(Icons.check_circle_rounded,
                                      color: AppColors.success, size: 18)
                                  : _isValid == false
                                      ? const Icon(Icons.error_outline_rounded,
                                          color: AppColors.error, size: 18)
                                      : null,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 42,
                        width:
                            72, // explicit width — prevents infinite-width crash
                        child: ElevatedButton(
                          onPressed: _isValidating ? null : _validateAndApply,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isValid == true
                                ? AppColors.success
                                : AppColors.primary,
                            foregroundColor: AppColors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                            padding: EdgeInsets.zero,
                          ),
                          child: _isValidating
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: AppColors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : _isValid == true
                                  ? const Icon(Icons.check_rounded, size: 20)
                                  : Text(
                                      AppLocalizations.of(context)!.apply,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700),
                                    ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Validation feedback ─────────────────────────
                if (_isValid == true)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.success, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.couponApplied,
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () =>
                                context.push(AppRoutes.userLocationSelect),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.bookNow,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isValid == false)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage ??
                                  AppLocalizations.of(context)!
                                      .invalidCouponCode,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
