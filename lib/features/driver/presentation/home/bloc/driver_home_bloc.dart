
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../../services/location_service.dart';
import '../../../../../services/heatmap_service.dart';
import '../data/driver_home_repository.dart';
import 'driver_home_event.dart';
import 'driver_home_state.dart';













class DriverHomeBloc extends Bloc<DriverHomeEvent, DriverHomeState> {
  final LocationService _locationService = LocationService();
  final HeatmapService _heatmapService = HeatmapService.instance;
  final DriverHomeRepository _repository = DriverHomeRepository();
  StreamSubscription? _locationSubscription;
  StreamSubscription? _tripsSubscription;
  StreamSubscription? _heatmapSubscription;

  
  bool _statusLoaded = false;

  
  
  static const int _maxTrackedIds = 200;
  final Set<String> _shownOfferTripIds = {};
  final Set<String> _rejectedOfferTripIds = {};

  void _trackId(Set<String> set, String id) {
    if (set.length >= _maxTrackedIds) {
      
      final toRemove = set.take(50).toList();
      set.removeAll(toRemove);
    }
    set.add(id);
  }

  DriverHomeBloc() : super(const DriverHomeState()) {
    on<LoadDriverStatus>(_onLoadDriverStatus);
    on<ToggleAvailability>(_onToggleAvailability);
    on<NewTripOfferReceived>(_onNewTripOffer);
    on<AcceptTripOffer>(_onAcceptTripOffer);
    on<RejectTripOffer>(_onRejectTripOffer);
    on<DriverLocationChanged>(_onLocationChanged);
    on<LoadHeatmapData>(_onLoadHeatmapData);
    on<HeatmapDataUpdated>(_onHeatmapDataUpdated);
    on<RefreshDriverLocation>(_onRefreshDriverLocation);
    on<ResetDriverStatus>(_onReset);
  }

  Future<void> _onReset(
    ResetDriverStatus event,
    Emitter<DriverHomeState> emit,
  ) async {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    _tripsSubscription?.cancel();
    _tripsSubscription = null;
    _pendingPushTimer?.cancel();
    _shownOfferTripIds.clear();
    _rejectedOfferTripIds.clear();
    _statusLoaded = false;
    emit(const DriverHomeState());
    debugPrint('🔄 DriverHomeBloc: Reset complete');
  }

  Future<void> _onLoadDriverStatus(
    LoadDriverStatus event,
    Emitter<DriverHomeState> emit,
  ) async {
    
    
    
    if (_statusLoaded) {
      debugPrint('📍 DriverHomeBloc: Status already loaded — skipping re-init');
      
      if (state.isAvailable && _locationSubscription == null) {
        final userId = SupabaseService.currentUser?.id;
        if (userId != null) await _startLocationTracking(userId);
      }
      return;
    }

    emit(state.copyWith(isLoading: true));
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) return;

      
      final statusData = await _repository.loadDriverStatus(userId);
      final driverData = statusData['driverData'];
      final userData = statusData['userData'];

      
      final earnings = await _repository.getEarningsSummary(userId);

      emit(state.copyWith(
        isAvailable: driverData['is_available'] as bool? ?? false,
        rating: (userData['rating'] as num?)?.toDouble() ?? 0,
        totalTrips: (userData['total_trips'] as int?) ?? 0,
        totalEarnings: earnings['totalEarnings'] as double? ?? 0,
        availableBalance: earnings['availableBalance'] as double? ?? 0,
        earningsThisWeek: earnings['earningsThisWeek'] as double? ?? 0,
        isLoading: false,
      ));

      try {
        final hasPermission = await _locationService.hasPermission();
        if (!hasPermission) {
          await _locationService.requestPermission();
        }
        final position = await _locationService.getCurrentLocation();
        emit(state.copyWith(
          driverLat: position.latitude,
          driverLng: position.longitude,
        ));

        bool shouldBeAvailable = driverData['is_available'] == true;
        if (shouldBeAvailable) {
          final hasActive = await _repository.hasActiveTrip(userId);
          if (hasActive) {
            debugPrint('⚠️ DriverHomeBloc: Driver has active trip, forcing offline status');
            await _repository.setDriverOffline(userId);
            shouldBeAvailable = false;
          } else {
            await _pushLocationToDb(
                userId, position.latitude, position.longitude, heading: position.heading);
          }
        }
        
        emit(state.copyWith(isAvailable: shouldBeAvailable));

        if (shouldBeAvailable) {
          await _startLocationTracking(userId);
          _subscribeToTripOffers(userId);
        }
      } catch (e) {
        debugPrint('⚠️ DriverHomeBloc: Could not get initial location: $e');
      }

      add(LoadHeatmapData());

      _statusLoaded = true;
    } catch (e) {
      debugPrint('❌ DriverHomeBloc: LoadDriverStatus failed: $e');
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onToggleAvailability(
    ToggleAvailability event,
    Emitter<DriverHomeState> emit,
  ) async {
    if (state.isLoading) {
      debugPrint('🚦 DriverHomeBloc: Ignored ToggleAvailability, already loading.');
      return;
    }
    debugPrint('🚦 DriverHomeBloc: ToggleAvailability → isAvailable=${event.isAvailable}');
    emit(state.copyWith(isLoading: true));
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ DriverHomeBloc: userId is null!');
        return;
      }

      if (event.isAvailable) {
        final hasActive = await _repository.hasActiveTrip(userId);
        if (hasActive) {
          debugPrint('⚠️ DriverHomeBloc: Cannot go online while on an active trip');
          emit(state.copyWith(isLoading: false, clearError: true));
          await Future.delayed(const Duration(milliseconds: 50));
          emit(state.copyWith(
            errorMessage: 'errorCannotGoOnlineDuringTrip',
          ));
          return;
        }
        
        final hasPermission = await _locationService.hasPermission();
        if (!hasPermission) {
          await _locationService.requestPermission();
        }
        
        final position = await _locationService.getCurrentLocation();
        final lat = position.latitude;
        final lng = position.longitude;

        await _repository.setDriverOnline(userId, lat, lng);

        debugPrint('✅ Driver ONLINE: lat=$lat, lng=$lng');

        emit(state.copyWith(
          isAvailable: true,
          driverLat: lat,
          driverLng: lng,
          isLoading: false,
        ));

        await _startLocationTracking(userId);
        _subscribeToTripOffers(userId);
      } else {
        
        
        
        await _repository.setDriverOffline(userId);

        debugPrint('🔴 Driver OFFLINE');

        await _locationSubscription?.cancel();
        await _tripsSubscription?.cancel();
        _locationSubscription = null;
        _tripsSubscription = null;

        emit(state.copyWith(isAvailable: false, isLoading: false, clearError: true));
      }
    } catch (e) {
      debugPrint('❌ DriverHomeBloc: ToggleAvailability failed: $e');
      emit(state.copyWith(isLoading: false, clearError: true));
      await Future.delayed(const Duration(milliseconds: 50));
      emit(state.copyWith(errorMessage: 'errorUnexpected'));
    }
  }

  void _onNewTripOffer(
    NewTripOfferReceived event,
    Emitter<DriverHomeState> emit,
  ) {
    final tripId = event.trip.id;
    _trackId(_shownOfferTripIds, tripId);
    emit(state.copyWith(pendingTripOffer: event.trip));
  }

  
  bool _isAccepting = false;

  Future<void> _onAcceptTripOffer(
    AcceptTripOffer event,
    Emitter<DriverHomeState> emit,
  ) async {
    
    if (_isAccepting) {
      debugPrint('🚦 DriverHomeBloc: Accept already in progress — ignoring');
      return;
    }
    _isAccepting = true;

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      debugPrint('❌ DriverHomeBloc: Cannot accept — not authenticated');
      _shownOfferTripIds.clear();
      _isAccepting = false;
      emit(state.copyWith(clearOffer: true));
      return;
    }

    debugPrint('🚦 DriverHomeBloc: Accepting trip ${event.tripId} for driver $userId');

    try {
      
      final result = await _repository.acceptTrip(event.tripId);

      debugPrint('🚦 DriverHomeBloc: driver_accept_trip result = $result');

      if (result != null && result['success'] == true) {
        _shownOfferTripIds.clear();
        _isAccepting = false;
        
        final acceptedTripId = result['trip_id'] as String? ?? event.tripId;
        
        // Disable Home tracking and set offline since they are now on a trip
        await _locationSubscription?.cancel();
        await _tripsSubscription?.cancel();
        _locationSubscription = null;
        _tripsSubscription = null;
        
        emit(state.copyWith(
          isAvailable: false,
          clearOffer: true,
          acceptedTripId: acceptedTripId,
        ));
        return;
      }

      debugPrint('⚠️ DriverHomeBloc: RPC accept returned error: ${result?['error'] ?? result}');
      
      
    } catch (rpcError) {
      debugPrint('⚠️ DriverHomeBloc: RPC accept failed ($rpcError). Trip likely unavailable.');
    }

    _isAccepting = false;
    _shownOfferTripIds.clear();
    emit(state.copyWith(clearOffer: true));
  }

  Future<void> _onRejectTripOffer(
    RejectTripOffer event,
    Emitter<DriverHomeState> emit,
  ) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      debugPrint('❌ DriverHomeBloc: Cannot reject — not authenticated');
      _trackId(_rejectedOfferTripIds, event.tripId);
      emit(state.copyWith(clearOffer: true));
      return;
    }

    debugPrint('🚦 DriverHomeBloc: Rejecting trip ${event.tripId} for driver $userId');

    try {
      final result = await _repository.rejectTrip(event.tripId);

      debugPrint('🚦 DriverHomeBloc: driver_reject_trip result = $result');
    } catch (rpcError) {
      debugPrint('⚠️ DriverHomeBloc: RPC reject failed ($rpcError).');
      
    }

    _trackId(_rejectedOfferTripIds, event.tripId);
    emit(state.copyWith(clearOffer: true));
  }

  Future<void> _onLocationChanged(
    DriverLocationChanged event,
    Emitter<DriverHomeState> emit,
  ) async {
    emit(state.copyWith(driverLat: event.lat, driverLng: event.lng));
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;
    if (!state.isAvailable) return;
    await _pushLocationToDb(userId, event.lat, event.lng, heading: event.heading);
  }

  
  
  Future<void> _onRefreshDriverLocation(
    RefreshDriverLocation event,
    Emitter<DriverHomeState> emit,
  ) async {
    if (!state.isAvailable) return;
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    try {
      final position = await _locationService.getCurrentLocation();
      emit(state.copyWith(
        driverLat: position.latitude,
        driverLng: position.longitude,
      ));
      await _pushLocationToDb(userId, position.latitude, position.longitude, heading: position.heading);
      debugPrint('🔄 DriverHomeBloc: Location refreshed after resume');
    } catch (e) {
      debugPrint('⚠️ DriverHomeBloc: RefreshDriverLocation failed: $e');
    }
  }

  DateTime? _lastLocationPushTime;
  Timer? _pendingPushTimer;
  double? _pendingLat;
  double? _pendingLng;
  double? _pendingHeading;

  /// Push location to DB with smart throttle.
  /// Instead of dropping throttled updates, stores the latest and schedules
  /// a delayed push so the user always sees the most recent position.
  Future<void> _pushLocationToDb(
      String userId, double lat, double lng, {double? heading}) async {
    final now = DateTime.now();
    final elapsed = _lastLocationPushTime != null
        ? now.difference(_lastLocationPushTime!).inSeconds
        : 999;

    if (elapsed < 5) {
      // Store the latest position and schedule a push when throttle expires
      _pendingLat = lat;
      _pendingLng = lng;
      _pendingHeading = heading;
      _pendingPushTimer ??= Timer(
        Duration(seconds: 5 - elapsed + 1),
        () {
          _pendingPushTimer = null;
          if (_pendingLat != null && _pendingLng != null && state.isAvailable) {
            final uid = SupabaseService.currentUser?.id;
            if (uid != null) {
              _doPushLocation(uid, _pendingLat!, _pendingLng!, heading: _pendingHeading);
            }
          }
          _pendingLat = null;
          _pendingLng = null;
          _pendingHeading = null;
        },
      );
      return;
    }

    _pendingPushTimer?.cancel();
    _pendingPushTimer = null;
    _pendingLat = null;
    _pendingLng = null;
    _pendingHeading = null;
    await _doPushLocation(userId, lat, lng, heading: heading);
  }

  Future<void> _doPushLocation(
      String userId, double lat, double lng, {double? heading}) async {
    _lastLocationPushTime = DateTime.now();
    try {
      await _repository.pushLocation(userId, lat, lng, heading: heading);
    } catch (e) {
      debugPrint('❌ DriverHomeBloc: Failed to push location: $e');
    }
  }

  Future<void> _onLoadHeatmapData(
    LoadHeatmapData event,
    Emitter<DriverHomeState> emit,
  ) async {
    
    if (_heatmapSubscription != null) return;
    await _heatmapService.startRealtimeUpdates();
    _heatmapSubscription = _heatmapService.heatmapUpdates.listen((cells) {
      add(HeatmapDataUpdated(cells));
    });
  }

  void _onHeatmapDataUpdated(
    HeatmapDataUpdated event,
    Emitter<DriverHomeState> emit,
  ) {
    emit(state.copyWith(heatmapCells: event.cells));
  }

  Future<void> _startLocationTracking(String userId) async {
    
    await _locationSubscription?.cancel();
    _locationSubscription = _locationService.getLocationStream().listen(
      (position) {
        add(DriverLocationChanged(
          lat: position.latitude,
          lng: position.longitude,
          heading: position.heading,
        ));
      },
      onError: (e) {
        debugPrint('❌ DriverHomeBloc: Location stream error: $e');
      },
    );
    debugPrint('📍 DriverHomeBloc: Location tracking started for $userId');
  }

  void _subscribeToTripOffers(String userId) {
    _tripsSubscription?.cancel();
    _tripsSubscription = _repository.getTripOffersStream(userId).listen((offers) async {
      
      final pendingTripIds = <String>{};
      for (final offer in offers) {
        if (offer['status'] != 'pending') continue;
        if (offer['responded_at'] != null) continue;
        final tripId = offer['trip_id'] as String?;
        if (tripId == null) continue;
        if (_rejectedOfferTripIds.contains(tripId)) continue;
        if (_shownOfferTripIds.contains(tripId)) continue;
        final currentOffer = state.pendingTripOffer;
        if (currentOffer != null && currentOffer.id == tripId) continue;
        pendingTripIds.add(tripId);
      }
      if (pendingTripIds.isEmpty) return;

      try {
        
        final hasActive = await _repository.hasActiveTrip(userId);
        if (hasActive) return;

        
        final tripList = await _repository.fetchTripsByIds(pendingTripIds.toList());

        for (final tripData in tripList) {
          final tripId = tripData.id;
          if (tripId.isEmpty) continue;
          _trackId(_shownOfferTripIds, tripId);
          add(NewTripOfferReceived(tripData));
          break; 
        }
      } catch (e) {
        debugPrint('❌ DriverHomeBloc: Failed to fetch trip offers: $e');
      }
    }, onError: (e) {
      debugPrint('❌ DriverHomeBloc: Trip stream error: $e');
    });
    debugPrint('🎧 DriverHomeBloc: Subscribed to trip offers for $userId');
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _tripsSubscription?.cancel();
    _heatmapSubscription?.cancel();
    _pendingPushTimer?.cancel();
    _heatmapService.stopRealtimeUpdates();
    return super.close();
  }
}
