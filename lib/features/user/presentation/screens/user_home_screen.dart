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
import '../../../../core/map/app_map.dart';
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
import '../../../../core/services/cell_subscription_service.dart';
import '../home/bloc/user_home_bloc.dart';
import '../home/bloc/user_home_event.dart';
import '../home/bloc/user_home_state.dart';
import '../../../../core/localization/generated/app_localizations.dart';
import 'auto_scroll_coupons.dart';
import 'package:snapix/core/utils/app_logger.dart';

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

  static const double _compactBottomSheetHeight = 190;
  static const double _couponBottomSheetHeight = 310;
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
      // وقف الـ Ticker لما لا يوجد حركة لتخفيف الحمل على الـ CPU
      if (!needsUpdate) {
        _animationTicker?.stop();
      }
    });
    // لا تبدأ الـ Ticker فوراً — يبدأ عند وصول بيانات سائقين عبر _updateDriverPositions
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

    // ابدأ الـ Ticker لو كان واقف وعندنا سائقين لتحريكهم
    if (_targetDriverPositions.isNotEmpty &&
        _animationTicker != null &&
        !_animationTicker!.isTicking) {
      _animationTicker!.start();
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

        // Refresh immediately — no delay needed.
        // CellSubscriptionService now re-fetches the snapshot on first Realtime
        // connect, so drivers who went online are already captured.
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
      AppLogger.warning('Failed to load car icon: $e');
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
        AppLogger.info('UserHome: Already loaded — skipping re-init');
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
        AppLogger.warning('UserHomeScreen: Location timeout: $e');

        if (mounted) {
          setState(() {
            _initialPosition = AppConstants.defaultMapCenter;
            _isLocating = false;
          });
        }
      }
    } catch (e) {
      AppLogger.error('UserHomeScreen: Failed to load initial location — $e');
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
      AppLogger.warning('UserHome: animateCamera failed: $e');
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
            return AppGoogleMap(
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
              markers: markers,
              padding: EdgeInsets.only(bottom: sheetHeight + 8),
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
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(AppRoutes.userLocationSelect),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: context.elevatedColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.divColor, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: context.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          AppLocalizations.of(context)!.searchDestination,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 13,
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
                  buildWhen: (prev, curr) {
                    // يُبنى فقط عند تغيير الكوبونات — ليس عند كل update للسائقين
                    if (prev is UserHomeLoaded && curr is UserHomeLoaded) {
                      return prev.coupons != curr.coupons;
                    }
                    return prev.runtimeType != curr.runtimeType;
                  },
                  builder: (context, state) {
                    if (state is UserHomeLoaded && state.coupons.isNotEmpty) {
                      final validCoupons = state.coupons
                          .map((uc) => uc['coupons'] as Map<String, dynamic>?)
                          .whereType<Map<String, dynamic>>()
                          .toList();

                      if (validCoupons.isNotEmpty) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (validCoupons.length == 1)
                              _CouponBanner(coupon: validCoupons.first)
                            else
                              AutoScrollCoupons(
                                coupons: validCoupons,
                                itemBuilder: (coupon) => _CouponBanner(coupon: coupon),
                              ),
                            const SizedBox(height: 12),
                            const _PromoBanner(),
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
    final titleColor = context.textPrimary;
    final subtitleColor = context.textSecondary;
    final codeBorder = AppColors.primary.withValues(alpha: isDark ? 0.58 : 0.54);
    const codeTextColor = AppColors.primary;
    final codeFill = context.elevatedColor;
    final badgeBg = AppColors.warning.withValues(alpha: isDark ? 0.2 : 0.1);
    const badgeText = AppColors.warning;
    final ticketGradient = [AppColors.warning, AppColors.warning.withValues(alpha: 0.8)];

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
            color: isDark ? AppColors.white.withValues(alpha: 0.04) : AppColors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.white.withValues(alpha: 0.08) : AppColors.black.withValues(alpha: 0.05),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                l.discountLimited,
                                textDirection: textDirection,
                                                                                style: const TextStyle(
                                                  color: badgeText,
                                                  fontSize: 9.8,
                                                  fontWeight: FontWeight.w700,
                                                  height: 1.15,
                                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 2),
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
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  height: 1.15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
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
                                  fontSize: 9.6,
                                  fontWeight: FontWeight.w500,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
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
                                  height: 30,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
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
                                            size: 18,
                                            color: _copied
                                                ? AppColors.success
                                                : codeTextColor,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Center(
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Text(
                                                code,
                                                maxLines: 1,
                                                style: const TextStyle(
                                                  color: codeTextColor,
                                                  fontSize: 14.5,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 3.2,
                                                  height: 1.1,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 28),
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
                    const SizedBox(width: 9),
                    ClipPath(
                      clipper: const _CouponTicketClipper(),
                      child: Container(
                        width: 70,
                        height: 72,
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
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                discountNumber,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 7),
                              child: Text(
                                l.discountOnAllTrips,
                                textAlign: TextAlign.center,
                                textDirection: textDirection,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 8.8,
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
              ],
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

class _PromoBanner extends StatelessWidget {
  const _PromoBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: context.elevatedColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.divColor,
          width: 1,
        ),
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

