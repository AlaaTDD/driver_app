// lib/features/user/presentation/home/bloc/user_home_bloc.dart
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

/// User Home BLoC — manages the cell-based nearby driver system.
///
/// Flow:
/// 1. InitUserHome → get user location
/// 2. Subscribe to cells around user via CellSubscriptionService
/// 3. Start location stream → if user moves to new cell, re-subscribe
/// 4. Receive realtime driver updates → update markers on map
///
/// Navigation safety:
/// - InitUserHome is idempotent: re-entry skips re-init if already loaded
/// - Location stream is guarded — only started once
/// - UserLocationObtained only triggers re-subscription on cell change
class UserHomeBloc extends Bloc<UserHomeEvent, UserHomeState> {
  final LocationService _locationService = LocationService();
  final CellSubscriptionService _cellService = CellSubscriptionService.instance;
  final UserPresenceService _presenceService = UserPresenceService.instance;
  StreamSubscription? _driverUpdatesSubscription;
  StreamSubscription? _locationStreamSubscription;

  // Guard: true once we've successfully initialized
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
    // ── Idempotency guard ─────────────────────────────────────────────
    // User navigated away and came back — bloc is still alive.
    // Don't re-init; the existing state and streams are still valid.
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

      // Subscribe to cell system for nearby drivers
      await _cellService.subscribeToCells(lat, lng);

      // Broadcast user presence so drivers see us on the heatmap
      await _presenceService.startBroadcasting(lat, lng);

      // Listen to realtime driver updates — cancel any previous sub first
      _driverUpdatesSubscription?.cancel();
      _driverUpdatesSubscription =
          _cellService.driverUpdates.listen((drivers) {
        add(DriversRealtimeUpdate(drivers));
      });

      // Start tracking user's location to detect cell changes
      // Guard: cancel existing stream before starting new one
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

      // Mark initialized
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
    final newCellId =
        GeohashHelper.encode(event.lat, event.lng, precision: 6);

    // Only re-subscribe to cells when user moves to a DIFFERENT cell
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

    // Update presence so driver's heatmap moves with us
    _presenceService.updateLocation(event.lat, event.lng);
  }

  void _onDriversUpdate(
    DriversRealtimeUpdate event,
    Emitter<UserHomeState> emit,
  ) {
    if (state is UserHomeLoaded) {
      emit((state as UserHomeLoaded).copyWith(nearbyDrivers: event.drivers));
    }
  }

  Future<void> _onLoadUserCoupons(
    LoadUserCoupons event,
    Emitter<UserHomeState> emit,
  ) async {
    try {
      final data = await SupabaseService.client
          .from('user_coupons')
          .select('*, coupons(*)')
          .eq('user_id', event.userId)
          .order('assigned_at', ascending: false);

      final unusedCoupons = (data as List)
          .where((json) => json['used_at'] == null)
          .toList();

      if (state is UserHomeLoaded) {
        emit((state as UserHomeLoaded).copyWith(
          coupons: List<Map<String, dynamic>>.from(unusedCoupons),
        ));
      }
    } catch (e) {
      debugPrint('⚠️ UserHomeBloc: Failed to load coupons: $e');
    }
  }

  @override
  Future<void> close() async {
    _driverUpdatesSubscription?.cancel();
    _locationStreamSubscription?.cancel();
    // FIX C04: NEVER dispose global singletons from a BLoC lifecycle.
    // Only stop this instance's specific broadcasts.
    await _presenceService.stopBroadcasting();
    // _cellService.dispose() REMOVED — singleton must outlive BLoC
    return super.close();
  }
}
