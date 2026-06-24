import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/utils/geohash_helper.dart';
import '../../../../../core/services/cell_subscription_service.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/supabase_service.dart';
import '../../../../../core/services/user_presence_service.dart';
import 'user_home_event.dart';
import 'user_home_state.dart';
import 'package:snapix/core/utils/app_logger.dart';

class UserHomeBloc extends Bloc<UserHomeEvent, UserHomeState> {
  final LocationService _locationService = LocationService.instance;
  final CellSubscriptionService _cellService = CellSubscriptionService.instance;
  final UserPresenceService _presenceService = UserPresenceService.instance;
  StreamSubscription? _driverUpdatesSubscription;
  StreamSubscription? _locationStreamSubscription;

  bool _initDone = false;

  UserHomeBloc() : super(UserHomeInitial()) {
    on<InitUserHome>(_onInit);
    on<UserLocationObtained>(_onLocationObtained);
    on<DriversRealtimeUpdate>(_onDriversUpdate);
    on<LoadUserCoupons>(_onLoadUserCoupons);
  }

  Future<void> _onInit(
    InitUserHome event,
    Emitter<UserHomeState> emit,
  ) async {
    if (_initDone && state is UserHomeLoaded) {
      AppLogger.info('UserHome: Already initialized — skipping re-init');
      return;
    }

    emit(UserHomeLocating());

    final hasPermission = await _locationService.hasPermission();
    if (!hasPermission) {
      await _locationService.requestPermission();
    }

    try {
      final position = await _locationService.getCurrentLocation();
      final lat = position.latitude;
      final lng = position.longitude;
      final cellId = GeohashHelper.encode(lat, lng, precision: 6);

      AppLogger.info('UserHome: User at ($lat, $lng) cell=$cellId');

      // 1. Subscribe FIRST to catch any emitted events from subscribeToCells
      _driverUpdatesSubscription?.cancel();
      _driverUpdatesSubscription = _cellService.driverUpdates.listen((drivers) {
        add(DriversRealtimeUpdate(drivers));
      });

      // 2. If Singleton already has data (Hot Reload), push it immediately
      if (_cellService.currentDrivers.isNotEmpty) {
        add(DriversRealtimeUpdate(_cellService.currentDrivers));
      }

      // 3. THEN subscribe. The service loads one snapshot and keeps realtime open.
      await _cellService.subscribeToCells(lat, lng);

      await _presenceService.startBroadcasting(lat: lat, lng: lng);

      _locationStreamSubscription?.cancel();
      _locationStreamSubscription =
          _locationService.getLocationStream().listen((pos) {
        add(UserLocationObtained(lat: pos.latitude, lng: pos.longitude));
      });

      emit(UserHomeLoaded(
        userLat: lat,
        userLng: lng,
        currentCellId: cellId,
        nearbyDrivers: _cellService.currentDrivers,
        coupons: const [],
      ));

      add(LoadUserCoupons(event.userId));

      _initDone = true;
    } catch (e) {
      AppLogger.error('UserHome: Failed to init: $e');
      emit(const UserHomeError('errorDetermineLocation'));
    }
  }

  Future<void> _onLocationObtained(
    UserLocationObtained event,
    Emitter<UserHomeState> emit,
  ) async {
    if (state is! UserHomeLoaded) return;
    final currentState = state as UserHomeLoaded;
    final newCellId = GeohashHelper.encode(event.lat, event.lng, precision: 6);

    if (newCellId != currentState.currentCellId) {
      AppLogger.debug(
          '📍 UserHome: Cell changed ${currentState.currentCellId} → $newCellId');
      await _cellService.subscribeToCells(event.lat, event.lng);
    }

    emit(currentState.copyWith(
      userLat: event.lat,
      userLng: event.lng,
      currentCellId: newCellId,
    ));

    await _presenceService.updateLocation(event.lat, event.lng);
  }

  void _onDriversUpdate(
    DriversRealtimeUpdate event,
    Emitter<UserHomeState> emit,
  ) {
    if (state is UserHomeLoaded) {
      emit((state as UserHomeLoaded).copyWith(
        nearbyDrivers: event.drivers,
        bumpDrivers: true, // force Equatable to see a new state every time
      ));
    }
  }

  Future<void> _onLoadUserCoupons(
    LoadUserCoupons event,
    Emitter<UserHomeState> emit,
  ) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      // أعمدة الكوبون اللازمة للعرض والتحقق
      const couponColumns =
          'id, code, title, discount_type, discount_value, max_discount, '
          'is_active, max_uses, used_count, budget_limit, spent_budget, '
          'first_ride_only, starts_at, expires_at, created_at';

      // 1. Public coupons the admin created (visible on every user's home)
      List<Map<String, dynamic>> publicData = [];
      try {
        publicData = (await SupabaseService.client
            .from('coupons')
            .select(couponColumns)
            .eq('is_active', true)
            .or('expires_at.is.null,expires_at.gt.$now')
            .order('created_at', ascending: false)
            .timeout(const Duration(seconds: 15)))
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      } catch (e) {
        AppLogger.warning('UserHomeBloc: Could not load public coupons: $e');
      }

      // Wrap public coupons in unified shape
      final publicCoupons = publicData
          .map((c) => <String, dynamic>{
                'user_id': event.userId,
                'used_at': null,
                'coupons': c,
              })
          .toList();

      // 2. User-specific coupons
      List<Map<String, dynamic>> userData = [];
      try {
        userData = (await SupabaseService.client
            .from('user_coupons')
            .select(
              'user_id, used_at, assigned_at, '
              'coupons(id, code, title, discount_type, discount_value, '
              'max_discount, is_active, max_uses, used_count, budget_limit, '
              'spent_budget, first_ride_only, starts_at, expires_at)',
            )
            .eq('user_id', event.userId)
            .isFilter('used_at', null)
            .order('assigned_at', ascending: false)
            .timeout(const Duration(seconds: 15)))
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
      } catch (e) {
        AppLogger.warning('UserHomeBloc: Could not load user coupons: $e');
      }

      // Merge deduplicated by coupon code (user-specific first)
      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];
      for (final row in [...userData, ...publicCoupons]) {
        final coupon = row['coupons'] as Map<String, dynamic>?;
        if (coupon == null) continue;
        final code = coupon['code']?.toString() ?? '';
                  if (code.isNotEmpty && seen.add(code)) {
            merged.add(Map<String, dynamic>.from(row));
          }
      }

      // Filter valid coupons ONLY
      final validMerged = <Map<String, dynamic>>[];
      
      // Check if user has trips for first_ride_only check
      bool hasTrips = false;
      try {
        final trips = await SupabaseService.client
            .from('trips')
            .select('id')
            .eq('user_id', event.userId)
            .eq('status', 'completed')
            .limit(1);
        hasTrips = trips.isNotEmpty;
      } catch (e) {
        AppLogger.warning('UserHomeBloc: Failed to check trips: $e');
      }

      final dtNow = DateTime.now().toUtc();

      for (final row in merged) {
        final coupon = row['coupons'] as Map<String, dynamic>?;
        if (coupon == null) continue;

        if (coupon['starts_at'] != null) {
          final start = DateTime.parse(coupon['starts_at']);
          if (dtNow.isBefore(start)) continue;
        }

        if (coupon['max_uses'] != null && coupon['used_count'] != null) {
          if ((coupon['used_count'] as int) >= (coupon['max_uses'] as int)) {
            continue;
          }
        }

        if (coupon['budget_limit'] != null && coupon['spent_budget'] != null) {
          if ((coupon['spent_budget'] as num) >= (coupon['budget_limit'] as num)) {
            continue;
          }
        }

        if (coupon['first_ride_only'] == true && hasTrips) {
          continue;
        }

        validMerged.add(row);
      }

      if (state is UserHomeLoaded) {
        emit((state as UserHomeLoaded).copyWith(coupons: validMerged));
        AppLogger.debug('🎟️ UserHomeBloc: Loaded ${validMerged.length} coupons');
      }
    } catch (e) {
      AppLogger.warning('UserHomeBloc: Failed to load coupons: $e');
    }
  }

  @override
  Future<void> close() async {
    _driverUpdatesSubscription?.cancel();
    _locationStreamSubscription?.cancel();

    // UserPresenceService & CellSubscriptionService are Singletons.
    // Their lifecycle is managed by:
    //   • LogoutCoordinator (sign-out)
    //   • TrackingBloc (stops presence when trip starts, restarts when done)
    //
    // Do NOT call stopBroadcasting() or dispose() here — this causes two bugs:
    //   1. User disappears from the driver's heatmap the moment MeetingPoint
    //      navigates to Searching (before any trip even starts).
    //   2. Race Condition: GoRouter builds the new UserHomeScreen and the new
    //      Bloc subscribes to the services BEFORE the old Bloc is disposed, so
    //      old close() would kill the services the new Bloc just started.

    return super.close();
  }
}
