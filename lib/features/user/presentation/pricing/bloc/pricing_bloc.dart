import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/errors/exceptions.dart';
import '../../../../../services/supabase_service.dart';
import 'package:snapix/features/user/data/repositories/coupon_repository.dart';
import 'pricing_event.dart';
import 'pricing_state.dart';

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
      // Fix #5: Read pricing_config first (updated by admin dashboard via
      // admin_update_pricing RPC). Fall back to vehicle_types if empty.
      List<Map<String, dynamic>> rows = [];

      try {
        final pcRows = await SupabaseService.client
            .from('pricing_config')
            .select(
                'vehicle_type, display_name, icon, base_fare, price_per_km, is_active, sort_order')
            .eq('is_active', true)
            .order('sort_order', ascending: true);

        if ((pcRows as List).isNotEmpty) {
          // Map pricing_config columns → VehicleTypeModel field names
          rows = pcRows
              .map((r) => <String, dynamic>{
                    'name': r['vehicle_type'],
                    'display_name': r['display_name'] ?? r['vehicle_type'],
                    'icon': r['icon'] ?? 'directions_car',
                    'base_fare': r['base_fare'],
                    'price_per_km': r['price_per_km'],
                  })
              .toList();
          debugPrint(
              '✅ PricingBloc: Loaded ${rows.length} types from pricing_config');
        }
      } catch (e, st) {
        debugPrint(
            '⚠️ PricingBloc: pricing_config load failed, using vehicle_types fallback: $e\n$st');
        // pricing_config may not have all columns yet — fall through
      }

      // Fallback: read from vehicle_types if pricing_config gave nothing
      if (rows.isEmpty) {
        final vtRows = await SupabaseService.client
            .from('vehicle_types')
            .select('name, display_name, icon, base_fare, price_per_km')
            .eq('is_active', true)
            .order('sort_order', ascending: true);
        rows = (vtRows as List).cast<Map<String, dynamic>>();
        debugPrint(
            '✅ PricingBloc: Loaded ${rows.length} types from vehicle_types (fallback)');
      }

      final types = rows.map((r) => VehicleTypeModel.fromJson(r)).toList();

      emit(VehicleTypesLoaded(vehicleTypes: types));
    } catch (e) {
      debugPrint('❌ PricingBloc: Failed to load vehicle types: $e');
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
                name: 'sedan',
                displayName: 'Sedan',
                icon: 'directions_car',
                baseFare: 8,
                pricePerKm: 7,
              ),
      );

      final result = await SupabaseService.client.rpc(
        'calculate_trip_price',
        params: {
          'p_vehicle_type': event.vehicleType,
          'p_distance_km': event.distanceKm,
        },
      );

      if (result == null) {
        throw ServerException('errorNullPrice');
      }
      final finalPrice = (result as num).toDouble();

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
