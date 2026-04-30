// lib/features/user/presentation/pricing/bloc/pricing_bloc.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/supabase_service.dart';
import '../data/coupon_repository.dart';
import 'pricing_event.dart';
import 'pricing_state.dart';

class PricingBloc extends Bloc<PricingEvent, PricingState> {
  final CouponRepository _couponRepository;

  // FIX S03: In-memory rate limiter for coupon attempts (brute-force protection)
  DateTime? _lastCouponAttempt;
  static const _minCouponInterval = Duration(seconds: 2);

  PricingBloc({CouponRepository? couponRepository})
      : _couponRepository = couponRepository ?? CouponRepository(),
        super(PricingInitial()) {
    on<LoadVehicleTypes>(_onLoadVehicleTypes);
    on<CalculatePrice>(_onCalculatePrice);
    on<ApplyCoupon>(_onApplyCoupon);
  }

  // ── Helper: extract current vehicle list from state ───────────────────────
  List<VehicleTypeModel> _currentTypes() {
    final s = state;
    if (s is VehicleTypesLoaded) return s.vehicleTypes;
    if (s is PricingCalculated) return s.vehicleTypes;
    if (s is CouponApplied) return s.vehicleTypes;
    if (s is PricingError) return s.vehicleTypes;
    return [];
  }

  // ── Load vehicle types from Supabase ─────────────────────────────────────
  Future<void> _onLoadVehicleTypes(
    LoadVehicleTypes event,
    Emitter<PricingState> emit,
  ) async {
    emit(PricingLoading());
    try {
      final rows = await SupabaseService.client
          .from('vehicle_types')
          .select('name, display_name, icon, base_fare, price_per_km')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final types = (rows as List)
          .map((r) => VehicleTypeModel.fromJson(r as Map<String, dynamic>))
          .toList();

      debugPrint('✅ PricingBloc: Loaded ${types.length} vehicle types from DB');
      emit(VehicleTypesLoaded(vehicleTypes: types));
    } catch (e) {
      debugPrint('❌ PricingBloc: Failed to load vehicle types: $e');
      // Fallback to 2 hardcoded types so the UI never breaks
      final fallback = [
        const VehicleTypeModel(
          name: 'sedan',
          displayName: 'Sedan',
          icon: 'directions_car',
          baseFare: 8,
          pricePerKm: 7,
        ),
        const VehicleTypeModel(
          name: 'motorcycle',
          displayName: 'Motorcycle',
          icon: 'two_wheeler',
          baseFare: 5,
          pricePerKm: 4,
        ),
      ];
      emit(VehicleTypesLoaded(vehicleTypes: fallback));
    }
  }

  // ── Calculate price for selected vehicle ─────────────────────────────────
  // FIX C11: Use server-side RPC instead of client-side calculation
  // This prevents malicious clients from manipulating the price
  Future<void> _onCalculatePrice(
    CalculatePrice event,
    Emitter<PricingState> emit,
  ) async {
    final types = _currentTypes();
    try {
      // Find matching vehicle type for UI display purposes
      final vehicle = types.firstWhere(
        (v) => v.name == event.vehicleType,
        orElse: () => types.isNotEmpty
            ? types.first
            : const VehicleTypeModel(
                name: 'sedan',
                displayName: 'Sedan',
                icon: 'directions_car',
                baseFare: 8,
                pricePerKm: 7,
              ),
      );

      // FIX C11: Call server-side RPC to calculate price securely
      final result = await SupabaseService.client.rpc(
        'calculate_trip_price',
        params: {
          'p_vehicle_type': event.vehicleType,
          'p_distance_km': event.distanceKm,
        },
      );

      final finalPrice = (result as num?)?.toDouble() ?? vehicle.baseFare;

      emit(PricingCalculated(
        vehicleTypes: types,
        basePrice: finalPrice,
        finalPrice: finalPrice,
        vehicleType: event.vehicleType,
        distanceKm: event.distanceKm,
      ));
    } catch (e) {
      debugPrint('❌ PricingBloc: CalculatePrice RPC failed: $e');
      emit(PricingError('errorCalculatePrice', vehicleTypes: types));
    }
  }

  // ── Apply coupon — delegated to CouponRepository ─────────────────────────
  Future<void> _onApplyCoupon(
    ApplyCoupon event,
    Emitter<PricingState> emit,
  ) async {
    final types = _currentTypes();

    // FIX S03: Rate limit coupon attempts
    if (_lastCouponAttempt != null &&
        DateTime.now().difference(_lastCouponAttempt!) < _minCouponInterval) {
      emit(PricingError('errorWaitBeforeRetry', vehicleTypes: types));
      return;
    }
    _lastCouponAttempt = DateTime.now();

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      emit(PricingError('errorNotLoggedIn', vehicleTypes: types));
      return;
    }

    final result = await _couponRepository.validateCoupon(
      couponCode: event.couponCode,
      originalPrice: event.originalPrice,
      userId: userId,
    );

    if (result.isSuccess) {
      emit(CouponApplied(
        vehicleTypes: types,
        couponCode: result.couponCode!,
        discount: result.discount!,
        finalPrice: result.finalPrice!,
      ));
    } else {
      emit(PricingError(result.errorKey!, vehicleTypes: types));
    }
  }
}
