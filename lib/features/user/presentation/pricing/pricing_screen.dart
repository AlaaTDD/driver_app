// lib/features/user/presentation/pricing/pricing_screen.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'bloc/pricing_bloc.dart';
import 'bloc/pricing_event.dart';
import 'bloc/pricing_state.dart';
import 'pricing_args.dart';
import '../../../../core/constants/env_constants.dart';
import '../../../../services/directions_service.dart';
import '../meeting_point/meeting_point_args.dart';
import '../location_selection/location_selection_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_extensions.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_routes.dart';
import '../../../../core/localization/generated/app_localizations.dart';

enum _PaymentMethod { cash, card }

/// Map icon name strings (from DB) to Flutter IconData
IconData _iconFromName(String name) {
  const map = <String, IconData>{
    'directions_car':       Icons.directions_car_rounded,
    'directions_car_filled': Icons.directions_car_filled_rounded,
    'two_wheeler':          Icons.two_wheeler_rounded,
    'airport_shuttle':      Icons.airport_shuttle_rounded,
    'local_taxi':           Icons.local_taxi_rounded,
    'electric_car':         Icons.electric_car_rounded,
    'motorcycle':           Icons.motorcycle_rounded,
    'bus_alert':            Icons.bus_alert_rounded,
  };
  return map[name] ?? Icons.directions_car_rounded;
}

class PricingScreen extends StatefulWidget {
  final PricingArgs? extra;

  const PricingScreen({super.key, required this.extra});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> with TickerProviderStateMixin {
  String _selectedVehicle = ''; // will be set to first type from DB
  _PaymentMethod _paymentMethod = _PaymentMethod.cash;
  final _couponCtrl = TextEditingController();
  bool _showCoupon = false;
  double _distanceKm = 0;
  List<LatLng> _routePoints = [];
  List<LatLng> _visiblePoints = [];
  AnimationController? _drawCtrl;
  Timer? _drawThrottle;
  final _mapCtrl = Completer<GoogleMapController>();

  static const double _sheetHeight = 420;

  @override
  void initState() {
    super.initState();
    _drawCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..addListener(_onDrawFrame);
    // Load vehicle types from DB first, then fetch route
    context.read<PricingBloc>().add(const LoadVehicleTypes());
    _fetchRouteAndDistance();
  }

  Future<void> _fetchRouteAndDistance() async {
    final a = widget.extra;
    if (a?.originLat == null || a?.destLat == null) return;
    final result = await DirectionsService.getRoute(
      originLat: a!.originLat!, originLng: a.originLng!,
      destLat: a.destLat!, destLng: a.destLng!,
      apiKey: EnvConstants.googleMapsApiKey,
    );
    if (!mounted) return;
    final km = result != null
        ? result.distanceKm
        : _haversine(a.originLat!, a.originLng!, a.destLat!, a.destLng!);
    setState(() {
      _distanceKm = km;
      _routePoints = result?.points ?? [];
    });
    if (_selectedVehicle.isNotEmpty) {
      context.read<PricingBloc>().add(CalculatePrice(_selectedVehicle, _distanceKm));
    }
    if (_routePoints.isNotEmpty) _drawCtrl?.forward(from: 0.0);
  }

  void _onDrawFrame() {
    if (_routePoints.isEmpty || _drawCtrl == null) return;
    final count = (_drawCtrl!.value * _routePoints.length).ceil().clamp(2, _routePoints.length);
    _visiblePoints = _routePoints.sublist(0, count);
    // FIX M04: Throttle setState to avoid 60 rebuilds of GoogleMap in 1.2s
    _drawThrottle?.cancel();
    _drawThrottle = Timer(const Duration(milliseconds: 50), () {
      if (mounted) setState(() {});
    });
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) * math.cos(_deg2rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _deg2rad(double deg) => deg * math.pi / 180;

  void _selectVehicle(String type) {
    setState(() => _selectedVehicle = type);
    if (_distanceKm > 0 && type.isNotEmpty) {
      context.read<PricingBloc>().add(CalculatePrice(type, _distanceKm));
    }
  }

  void _goToMeetingPoint(double price, PricingState state) {
    final a = widget.extra;
    context.push(AppRoutes.userMeetingPoint, extra: MeetingPointArgs(
      originLat: a?.originLat, originLng: a?.originLng, originAddress: a?.originAddress,
      destLat: a?.destLat, destLng: a?.destLng, destAddress: a?.destAddress,
      distanceKm: _distanceKm, price: price, vehicleType: _selectedVehicle,
      paymentMethod: _paymentMethod == _PaymentMethod.cash ? 'cash' : 'card',
      couponCode: state is CouponApplied ? state.couponCode : null,
    ));
  }

  @override
  void dispose() {
    _drawCtrl?.dispose();
    _couponCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final args = widget.extra;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // ── Full-screen map ───────────────────────────────────────────────
          Positioned.fill(child: _buildMap(isDark, args)),

          // ── Top bar: back + trip card ─────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 8, offset: const Offset(0, 2))],
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TripRouteCard(
                        origin: args?.originAddress ?? '',
                        destination: args?.destAddress ?? '',
                        distanceKm: _distanceKm,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom sheet ──────────────────────────────────────────────────
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: BlocBuilder<PricingBloc, PricingState>(
              builder: (ctx, state) => _buildBottomSheet(ctx, state, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark, PricingArgs? args) {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    if (args?.originLat != null && args?.destLat != null) {
      final origin = LatLng(args!.originLat!, args.originLng!);
      final dest = LatLng(args.destLat!, args.destLng!);
      markers.addAll([
        Marker(markerId: const MarkerId('o'), position: origin,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)),
        Marker(markerId: const MarkerId('d'), position: dest,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)),
      ]);
      if (_visiblePoints.length >= 2) {
        polylines.add(Polyline(
          polylineId: const PolylineId('route_halo'),
          points: _visiblePoints,
          color: AppColors.primary.withValues(alpha: 0.10),
          width: 18,
        ));
        polylines.add(Polyline(
          polylineId: const PolylineId('route_glow'),
          points: _visiblePoints,
          color: AppColors.primary.withValues(alpha: 0.28),
          width: 10,
        ));
        polylines.add(Polyline(
          polylineId: const PolylineId('route'),
          points: _visiblePoints,
          color: AppColors.primary,
          width: 4,
        ));
      }
    }
    final initPos = args?.originLat != null
        ? CameraPosition(target: LatLng(args!.originLat!, args.originLng!), zoom: 13)
        : const CameraPosition(target: AppConstants.defaultMapCenter, zoom: 13);

    return GoogleMap(
      initialCameraPosition: initPos,
      onMapCreated: (ctrl) {
        if (!_mapCtrl.isCompleted) {
          _mapCtrl.complete(ctrl);
          if (args?.originLat != null && args?.destLat != null) {
            Future.delayed(const Duration(milliseconds: 400), () {
              const eps = 0.003;
              final minLat = math.min(args!.originLat!, args.destLat!);
              final maxLat = math.max(args.originLat!, args.destLat!);
              final minLng = math.min(args.originLng!, args.destLng!);
              final maxLng = math.max(args.originLng!, args.destLng!);
              final bounds = LatLngBounds(
                southwest: LatLng(minLat - (maxLat == minLat ? eps : 0), minLng - (maxLng == minLng ? eps : 0)),
                northeast: LatLng(maxLat + (maxLat == minLat ? eps : 0), maxLng + (maxLng == minLng ? eps : 0)),
              );
              ctrl.animateCamera(CameraUpdate.newLatLngBounds(bounds, 90));
            });
          }
        }
      },
      markers: markers,
      polylines: polylines,
      myLocationEnabled: false,
      zoomControlsEnabled: false,
      style: isDark ? kDarkMapStyle : kLightMapStyle,
      padding: EdgeInsets.only(bottom: _sheetHeight, top: 110),
    );
  }

  /// Auto-select first vehicle from loaded types if none selected yet
  void _onVehicleTypesLoaded(List<VehicleTypeModel> types) {
    if (types.isNotEmpty && _selectedVehicle.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _selectedVehicle = types.first.name);
        if (_distanceKm > 0) {
          context.read<PricingBloc>().add(CalculatePrice(types.first.name, _distanceKm));
        }
      });
    }
  }

  /// Build dynamic vehicle chip row from DB data
  Widget _buildVehicleList(PricingState state) {
    List<VehicleTypeModel> types = [];
    if (state is VehicleTypesLoaded) {
      types = state.vehicleTypes;
      _onVehicleTypesLoaded(types);
    } else if (state is PricingCalculated) {
      types = state.vehicleTypes;
    } else if (state is CouponApplied) {
      types = state.vehicleTypes;
    } else if (state is PricingError) {
      types = state.vehicleTypes;
    }

    if (types.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2)),
      );
    }

    return Row(
      children: types.asMap().entries.expand((entry) {
        final idx = entry.key;
        final v = entry.value;
        return [
          Expanded(
            child: _VehicleChip(
              type: v.name,
              label: v.displayName,
              icon: _iconFromName(v.icon),
              basePrice: '${v.baseFare.toStringAsFixed(0)} ${AppLocalizations.of(context)!.currencySar}',
              selected: _selectedVehicle == v.name,
              onTap: () => _selectVehicle(v.name),
            ),
          ),
          if (idx < types.length - 1) const SizedBox(width: 8),
        ];
      }).toList(),
    );
  }

  Widget _buildBottomSheet(BuildContext context, PricingState state, bool isDark) {

    return Container(
      constraints: BoxConstraints(maxHeight: _sheetHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1526) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(0, -4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -1)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 14),
            decoration: BoxDecoration(color: context.divColor, borderRadius: BorderRadius.circular(100)),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Vehicle selection (dynamic from DB) ──────────────────
                  Row(children: [
                    Container(
                      width: 4, height: 16,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.vehicleType, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 10),
                  _buildVehicleList(state),
                  const SizedBox(height: 14),

                  // ── Payment method ───────────────────────────────────────
                  Row(children: [
                    Container(
                      width: 4, height: 16,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
                    ),
                    const SizedBox(width: 8),
                    Text(AppLocalizations.of(context)!.paymentMethod, style: TextStyle(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    _PaymentChip(label: AppLocalizations.of(context)!.cash, icon: Icons.payments_rounded, selected: _paymentMethod == _PaymentMethod.cash, onTap: () => setState(() => _paymentMethod = _PaymentMethod.cash)),
                    const SizedBox(width: 8),
                    _PaymentChip(label: AppLocalizations.of(context)!.bankCard, icon: Icons.credit_card_rounded, selected: _paymentMethod == _PaymentMethod.card, onTap: () => setState(() => _paymentMethod = _PaymentMethod.card)),
                  ]),
                  const SizedBox(height: 12),

                  // ── Coupon ───────────────────────────────────────────────
                  GestureDetector(
                    onTap: () => setState(() => _showCoupon = !_showCoupon),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: context.elevatedColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        const Icon(Icons.local_offer_rounded, color: AppColors.primary, size: 15),
                        const SizedBox(width: 8),
                        Text(AppLocalizations.of(context)!.haveDiscountCoupon, style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Icon(_showCoupon ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 20),
                      ]),
                    ),
                  ),
                  if (_showCoupon) ...[
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _couponCtrl,
                          style: TextStyle(color: context.textPrimary, fontSize: 13),
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.enterDiscountCode,
                            hintStyle: TextStyle(color: context.textSecondary, fontSize: 13),
                            filled: true, fillColor: context.elevatedColor,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_couponCtrl.text.isNotEmpty && state is PricingCalculated) {
                              context.read<PricingBloc>().add(ApplyCoupon(_couponCtrl.text, state.finalPrice));
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                          child: Text(AppLocalizations.of(context)!.apply, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ]),
                  ],

                  // ── Price summary + confirm ───────────────────────────────
                  if (state is PricingCalculated || state is CouponApplied) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: context.elevatedColor, borderRadius: BorderRadius.circular(14)),
                      child: _buildPriceSummary(context, state),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          if (state is CouponApplied) {
                            _goToMeetingPoint(state.finalPrice, state);
                          } else if (state is PricingCalculated) {
                            _goToMeetingPoint(state.finalPrice, state);
                          }
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 6, shadowColor: AppColors.primary.withValues(alpha: 0.4)),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.place_rounded, size: 16),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.selectMeetingPoint, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                    ),
                  ] else
                    const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSummary(BuildContext context, PricingState state) {
    if (state is CouponApplied) {
      return Column(children: [
        _PriceRow(label: AppLocalizations.of(context)!.basePrice, value: state.finalPrice + state.discount),
        _PriceRow(label: AppLocalizations.of(context)!.discount, value: -state.discount, isDiscount: true),
        Divider(color: context.divColor, height: 16),
        _PriceRow(label: AppLocalizations.of(context)!.total, value: state.finalPrice, isTotal: true),
      ]);
    }
    final s = state as PricingCalculated;
    return Column(children: [
      _PriceRow(label: AppLocalizations.of(context)!.basePrice, value: s.basePrice),
      Divider(color: context.divColor, height: 16),
      _PriceRow(label: AppLocalizations.of(context)!.total, value: s.finalPrice, isTotal: true),
    ]);
  }
}

// ─── Trip Route Card ──────────────────────────────────────────────────────────

class _TripRouteCard extends StatelessWidget {
  final String origin, destination;
  final double distanceKm;
  final bool isDark;
  const _TripRouteCard({required this.origin, required this.destination, required this.distanceKm, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1526) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          // Route indicator
          Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.success,
                  boxShadow: [BoxShadow(color: AppColors.success.withValues(alpha: 0.4), blurRadius: 4)]),
            ),
            Container(
              width: 1.5, height: 22,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [AppColors.success.withValues(alpha: 0.6), AppColors.error.withValues(alpha: 0.6)],
                ),
              ),
            ),
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: AppColors.error,
                  boxShadow: [BoxShadow(color: AppColors.error.withValues(alpha: 0.4), blurRadius: 4)]),
            ),
          ]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(
                origin.isNotEmpty ? origin : AppLocalizations.of(context)!.startingPoint,
                style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
              Divider(color: context.divColor, height: 12),
              Text(
                destination.isNotEmpty ? destination : AppLocalizations.of(context)!.destination,
                style: TextStyle(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          if (distanceKm > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: context.primaryTint,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), width: 0.8),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('${distanceKm.toStringAsFixed(1)}', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w800)),
                Text(AppLocalizations.of(context)!.km, style: TextStyle(color: AppColors.primary.withValues(alpha: 0.7), fontSize: 9, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Vehicle Chip ─────────────────────────────────────────────────────────────

class _VehicleChip extends StatelessWidget {
  final String type, label, basePrice;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _VehicleChip({required this.type, required this.label, required this.icon, required this.basePrice, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.elevatedColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? AppColors.primary : context.divColor, width: selected ? 1.5 : 1),
          boxShadow: selected ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: selected ? Colors.white : context.textSecondary, size: 26),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(color: selected ? Colors.white : context.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(basePrice, style: TextStyle(color: selected ? Colors.white.withValues(alpha: 0.8) : context.textSecondary, fontSize: 10.5), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}

// ─── Payment Chip ─────────────────────────────────────────────────────────────

class _PaymentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PaymentChip({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? context.primaryTint : context.elevatedColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? AppColors.primary : context.divColor, width: selected ? 1.5 : 1),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: selected ? AppColors.primary : context.textSecondary, size: 20),
            const SizedBox(width: 7),
            Text(label, style: TextStyle(color: selected ? AppColors.primary : context.textPrimary, fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ]),
        ),
      ),
    );
  }
}

// ─── Price Row ────────────────────────────────────────────────────────────────

class _PriceRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isTotal;
  final bool isDiscount;
  const _PriceRow({required this.label, required this.value, this.isTotal = false, this.isDiscount = false});

  @override
  Widget build(BuildContext context) {
    final color = isDiscount ? AppColors.success : (isTotal ? AppColors.primary : context.textPrimary);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: context.textSecondary, fontSize: isTotal ? 15 : 13, fontWeight: isTotal ? FontWeight.w700 : FontWeight.w400)),
        Text('${isDiscount && value < 0 ? "-" : ""}${value.abs().toStringAsFixed(2)} ${AppLocalizations.of(context)!.currencySar}',
            style: TextStyle(color: color, fontSize: isTotal ? 16 : 13, fontWeight: isTotal ? FontWeight.w800 : FontWeight.w500),
            textDirection: TextDirection.ltr),
      ],
    );
  }
}

