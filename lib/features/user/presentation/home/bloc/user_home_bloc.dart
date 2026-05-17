import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/utils/geohash_helper.dart';
import '../../../../../services/cell_subscription_service.dart';
import '../../../../../services/location_service.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../../services/user_presence_service.dart';
import 'user_home_event.dart';
import 'user_home_state.dart';

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
      debugPrint('📍 UserHome: Already initialized — skipping re-init');
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

      debugPrint('📍 UserHome: User at ($lat, $lng) cell=$cellId');

      await _cellService.subscribeToCells(lat, lng);

      await _presenceService.startBroadcasting(lat: lat, lng: lng);

      _driverUpdatesSubscription?.cancel();
      _driverUpdatesSubscription = _cellService.driverUpdates.listen((drivers) {
        add(DriversRealtimeUpdate(drivers));
      });

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
      debugPrint('❌ UserHome: Failed to init: $e');
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
      debugPrint(
          '📍 UserHome: Cell changed ${currentState.currentCellId} → $newCellId');
      await _cellService.subscribeToCells(event.lat, event.lng);
    }

    emit(currentState.copyWith(
      userLat: event.lat,
      userLng: event.lng,
      currentCellId: newCellId,
    ));

    _presenceService.updateLocation(event.lat, event.lng);
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

      // 1. Public coupons the admin created (visible on every user's home)
      List<dynamic> publicData = [];
      try {
        publicData = await SupabaseService.client
            .from('coupons')
            .select()
            .eq('is_active', true)
            .or('expires_at.is.null,expires_at.gt.$now')
            .order('created_at', ascending: false);
      } catch (e, st) {
        debugPrint(
            '⚠️ UserHomeBloc: pricing_config coupon query failed: $e\n$st');
        // fallback if is_active column doesn't exist
        try {
          publicData = await SupabaseService.client
              .from('coupons')
              .select()
              .or('expires_at.is.null,expires_at.gt.$now')
              .order('created_at', ascending: false);
        } catch (e2) {
          debugPrint('⚠️ UserHomeBloc: Could not load public coupons: $e2');
        }
      }

      // Wrap public coupons in unified shape
      final publicCoupons = publicData
          .map((c) => <String, dynamic>{
                'user_id': event.userId,
                'used_at': null,
                'coupons': c as Map<String, dynamic>,
              })
          .toList();

      // 2. User-specific coupons
      List<dynamic> userData = [];
      try {
        userData = await SupabaseService.client
            .from('user_coupons')
            .select('*, coupons(*)')
            .eq('user_id', event.userId)
            .isFilter('used_at', null)
            .order('assigned_at', ascending: false);
      } catch (e) {
        debugPrint('⚠️ UserHomeBloc: Could not load user coupons: $e');
      }

      // Merge deduplicated by coupon code (user-specific first)
      final seen = <String>{};
      final merged = <Map<String, dynamic>>[];
      for (final row in [...userData, ...publicCoupons]) {
        final coupon = row['coupons'] as Map<String, dynamic>?;
        if (coupon == null) continue;
        final code = coupon['code']?.toString() ?? '';
        if (code.isNotEmpty && seen.add(code)) {
          merged.add(Map<String, dynamic>.from(row as Map));
        }
      }

      if (state is UserHomeLoaded) {
        emit((state as UserHomeLoaded).copyWith(coupons: merged));
        debugPrint('🎟️ UserHomeBloc: Loaded ${merged.length} coupons');
      }
    } catch (e) {
      debugPrint('⚠️ UserHomeBloc: Failed to load coupons: $e');
    }
  }

  @override
  Future<void> close() async {
    _driverUpdatesSubscription?.cancel();
    _locationStreamSubscription?.cancel();

    await _presenceService.stopBroadcasting();
    await _cellService.dispose();

    return super.close();
  }
}
