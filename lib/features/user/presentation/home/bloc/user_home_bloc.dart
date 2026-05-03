
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
  final LocationService _locationService = LocationService();
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

      
      await _presenceService.startBroadcasting(lat, lng);

      
      _driverUpdatesSubscription?.cancel();
      _driverUpdatesSubscription =
          _cellService.driverUpdates.listen((drivers) {
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
    final newCellId =
        GeohashHelper.encode(event.lat, event.lng, precision: 6);

    
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
    
    
    await _presenceService.stopBroadcasting();
    
    return super.close();
  }
}
