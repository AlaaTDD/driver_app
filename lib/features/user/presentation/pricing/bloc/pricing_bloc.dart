import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/services/supabase_service.dart';
import 'package:snapix/features/user/data/repositories/coupon_repository.dart';
import 'pricing_event.dart';
import 'pricing_state.dart';
import 'package:snapix/core/utils/app_logger.dart';

class PricingBloc extends Bloc<PricingEvent, PricingState> {
  final CouponRepository _couponRepository;

  DateTime? _lastCouponAttempt;
  static const _minCouponInterval = Duration(seconds: 2);

  PricingBloc({CouponRepository? couponRepository})
      : _couponRepository = couponRepository ?? CouponRepository(),
        super(PricingInitial()) {
    on<LoadVehicleTypes>(_onLoadVehicleTypes);
    on<CalculatePrice>(_onCalculatePrice);
    on<ApplyCoupon>(_onApplyCoupon);
  }

  List<VehicleTypeModel> _currentTypes() {
    final s = state;
    if (s is VehicleTypesLoaded) return s.vehicleTypes;
    if (s is PricingCalculated) return s.vehicleTypes;
    if (s is CouponApplied) return s.vehicleTypes;
    if (s is PricingError) return s.vehicleTypes;
    return [];
  }

  Future<void> _onLoadVehicleTypes(
    LoadVehicleTypes event,
    Emitter<PricingState> emit,
  ) async {
    emit(PricingLoading());
    try {
      // Phase 3: Read directly from service_tiers
      final stRows = await SupabaseService.client
          .from('service_tiers')
          .select(
              'id, name, display_name, icon, base_fare, price_per_km, minimum_fare, is_active, sort_order')
          .eq('is_active', true)
          .order('sort_order', ascending: true);

      final rows = (stRows as List).cast<Map<String, dynamic>>();
      AppLogger.debug(
          '✅ PricingBloc: Loaded ${rows.length} service tiers');

      final types = rows.map((r) => VehicleTypeModel.fromJson(r)).toList();

      emit(VehicleTypesLoaded(vehicleTypes: types));
    } catch (e) {
      AppLogger.error('PricingBloc: Failed to load service tiers: $e');
      emit(PricingError('errorLoadVehicleTypes', vehicleTypes: []));
    }
  }

  Future<void> _onCalculatePrice(
    CalculatePrice event,
    Emitter<PricingState> emit,
  ) async {
    final types = _currentTypes();
    try {
      final vehicle = types.firstWhere(
        (v) => v.name == event.vehicleType,
        orElse: () => types.isNotEmpty
            ? types.first
            : const VehicleTypeModel(
                id: '', // no real service_tier resolved — matches fromJson's empty-id fallback
                name: 'sedan',
                displayName: 'Sedan',
                icon: 'directions_car',
                baseFare: 8,
                pricePerKm: 7,
              ),
      );

      // Phase 3: Calculate client-side (calculate_trip_price RPC removed)
      final rawPrice = vehicle.baseFare + vehicle.pricePerKm * event.distanceKm;
      final finalPrice = rawPrice < vehicle.minimumFare && vehicle.minimumFare > 0
          ? vehicle.minimumFare
          : rawPrice;

      emit(PricingCalculated(
        vehicleTypes: types,
        basePrice: finalPrice,
        finalPrice: finalPrice,
        vehicleType: event.vehicleType,
        serviceTierId: vehicle.id,
        distanceKm: event.distanceKm,
      ));
    } catch (e) {
      AppLogger.error('PricingBloc: CalculatePrice RPC failed: $e');
      emit(PricingError('errorCalculatePrice', vehicleTypes: types));
    }
  }

  Future<void> _onApplyCoupon(
    ApplyCoupon event,
    Emitter<PricingState> emit,
  ) async {
    final types = _currentTypes();

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
      // Save valid coupon to user wallet
      try {
        await _couponRepository.assignCouponToUser(result.couponCode!, userId);
      } catch (e) {
        AppLogger.warning('PricingBloc: Failed to assign coupon: $e');
      }

      emit(CouponApplied(
        vehicleTypes: types,
        couponCode: result.couponCode!,
        discount: result.discount!,
        finalPrice: result.finalPrice!,
      ));
    } else {
      final s = state;
      if (s is PricingCalculated) {
        emit(CouponApplyError(
          errorMessage: result.errorKey!,
          vehicleTypes: types,
          basePrice: s.basePrice,
          finalPrice: s.finalPrice,
          vehicleType: s.vehicleType,
          serviceTierId: s.serviceTierId,
          distanceKm: s.distanceKm,
        ));
        emit(PricingCalculated(
          vehicleTypes: types,
          basePrice: s.basePrice,
          finalPrice: s.finalPrice,
          vehicleType: s.vehicleType,
          serviceTierId: s.serviceTierId,
          distanceKm: s.distanceKm,
        ));
      } else if (s is CouponApplied) {
        emit(PricingError(result.errorKey!, vehicleTypes: types));
        emit(CouponApplied(
          vehicleTypes: types,
          couponCode: s.couponCode,
          discount: s.discount,
          finalPrice: s.finalPrice,
        ));
      } else {
        emit(PricingError(result.errorKey!, vehicleTypes: types));
      }
    }
  }
}
