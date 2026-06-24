import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../../core/services/supabase_service.dart';
import '../../../../../core/services/location_service.dart';
import '../../../../../core/services/heatmap_service.dart';
import 'package:snapix/features/driver/data/repositories/driver_home_repository.dart';
import 'package:snapix/features/driver/data/repositories/trip_details_repository.dart';
import 'driver_home_event.dart';
import 'driver_home_state.dart';
import 'package:snapix/core/utils/app_logger.dart';

class DriverHomeBloc extends Bloc<DriverHomeEvent, DriverHomeState> {
  final LocationService _locationService;
  final HeatmapService _heatmapService;
  final DriverHomeRepository _repository;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _tripsSubscription;
  StreamSubscription? _heatmapSubscription;
  // يلتقط تغييرات is_available من الداتابيز (cron الـ 15 دقيقة، admin، إلخ)
  // عشان الزر يفضل مرآة لمصدر الحقيقة بدل ما يكون state محلية معزولة.
  StreamSubscription<bool?>? _availabilitySyncSub;

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

  DriverHomeBloc({
    LocationService? locationService,
    HeatmapService? heatmapService,
    DriverHomeRepository? repository,
  })  : _locationService = locationService ?? LocationService(),
        _heatmapService = heatmapService ?? HeatmapService.instance,
        _repository = repository ?? DriverHomeRepository(),
        super(const DriverHomeState()) {
    on<LoadDriverStatus>(_onLoadDriverStatus);
    on<ToggleAvailability>(_onToggleAvailability);
    on<AvailabilitySynced>(_onAvailabilitySynced);
    on<NewTripOfferReceived>(_onNewTripOffer);
    on<AcceptTripOffer>(_onAcceptTripOffer);
    on<RejectTripOffer>(_onRejectTripOffer);
    on<SubmitTripOffer>(_onSubmitTripOffer);
    on<DriverLocationChanged>(_onLocationChanged);
    on<LoadHeatmapData>(_onLoadHeatmapData);
    on<HeatmapDataUpdated>(_onHeatmapDataUpdated);
    on<RefreshDriverLocation>(_onRefreshDriverLocation);
    on<DriverAppPaused>(_onDriverAppPaused);
    on<DriverAppResumed>(_onDriverAppResumed);
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
    _availabilitySyncSub?.cancel();
    _availabilitySyncSub = null;
    _lastPushedLat = null;
    _lastPushedLng = null;
    _shownOfferTripIds.clear();
    _rejectedOfferTripIds.clear();
    _wasOnlineBeforeLifecyclePause = false;
    _statusLoaded = false;
    emit(const DriverHomeState());
    AppLogger.info('DriverHomeBloc: Reset complete');
  }

  Future<void> _onLoadDriverStatus(
    LoadDriverStatus event,
    Emitter<DriverHomeState> emit,
  ) async {
    if (_statusLoaded) {
      AppLogger.info(
          'DriverHomeBloc: Status already loaded — skipping re-init');

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

      // ابدأ الـ realtime sync على is_available — يفضل شغّال طول ما الشاشة
      // مفتوحة عشان يلتقط تغييرات الـ cron (15 د) أو الـ admin فورًا.
      _subscribeToAvailability(userId);

      final earnings = await _repository.getEarningsSummary(userId);

      emit(state.copyWith(
        isAvailable: driverData['is_available'] as bool? ?? false,
        rating: (userData['rating'] as num?)?.toDouble() ?? 0,
        totalTrips: (userData['total_trips'] as int?) ?? 0,
        totalEarnings: earnings.totalEarnings,
        availableBalance: earnings.availableBalance,
        earningsThisWeek: earnings.earningsThisWeek,
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
            AppLogger.debug(
                '⚠️ DriverHomeBloc: Driver has active trip, forcing offline status');
            await _repository.setDriverOffline(userId);
            shouldBeAvailable = false;
          } else {
            await _pushLocationToDb(
                userId, position.latitude, position.longitude,
                force: true, heading: position.heading);
          }
        }

        emit(state.copyWith(isAvailable: shouldBeAvailable));

        if (shouldBeAvailable) {
          await _startLocationTracking(userId);
          _subscribeToTripOffers(userId);
        }
      } catch (e) {
        AppLogger.warning('DriverHomeBloc: Could not get initial location: $e');
      }

      add(LoadHeatmapData());

      _statusLoaded = true;
    } catch (e) {
      AppLogger.error('DriverHomeBloc: LoadDriverStatus failed: $e');
      emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> _onToggleAvailability(
    ToggleAvailability event,
    Emitter<DriverHomeState> emit,
  ) async {
    if (state.isLoading) {
      AppLogger.debug(
          '🚦 DriverHomeBloc: Ignored ToggleAvailability, already loading.');
      return;
    }
    AppLogger.debug(
        '🚦 DriverHomeBloc: ToggleAvailability → isAvailable=${event.isAvailable}');
    emit(state.copyWith(isLoading: true));
    try {
      final userId = SupabaseService.currentUser?.id;
      if (userId == null) {
        AppLogger.error('DriverHomeBloc: userId is null!');
        return;
      }

      if (event.isAvailable) {
        final hasActive = await _repository.hasActiveTrip(userId);
        if (hasActive) {
          AppLogger.debug(
              '⚠️ DriverHomeBloc: Cannot go online while on an active trip');
          emit(state.copyWith(
            isLoading: false,
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
        _markLocationPushed(lat, lng);

        AppLogger.info('Driver ONLINE: lat=$lat, lng=$lng');

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

        AppLogger.info('Driver OFFLINE');

        _wasOnlineBeforeLifecyclePause = false;
        _lastPushedLat = null;
        _lastPushedLng = null;

        await _locationSubscription?.cancel();
        await _tripsSubscription?.cancel();
        _locationSubscription = null;
        _tripsSubscription = null;

        emit(state.copyWith(
            isAvailable: false, isLoading: false, clearError: true));
      }
    } catch (e) {
      AppLogger.error('DriverHomeBloc: ToggleAvailability failed: $e');
      emit(state.copyWith(isLoading: false, errorMessage: 'errorUnexpected'));
    }
  }

  bool _wasOnlineBeforeLifecyclePause = false;
  bool _isHandlingLifecycle = false;
  bool _resumeRequestedDuringLifecycle = false;

  Future<void> _onDriverAppPaused(
    DriverAppPaused event,
    Emitter<DriverHomeState> emit,
  ) async {
    if (_isHandlingLifecycle) return;
    if (!state.isAvailable) return;

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    _isHandlingLifecycle = true;
    _wasOnlineBeforeLifecyclePause = true;

    try {
      await _repository.setDriverOffline(userId);
      await _locationSubscription?.cancel();
      await _tripsSubscription?.cancel();
      _locationSubscription = null;
      _tripsSubscription = null;
      _lastPushedLat = null;
      _lastPushedLng = null;

      emit(state.copyWith(isAvailable: false, isLoading: false));
      AppLogger.info('Driver OFFLINE: app left foreground');
    } catch (e) {
      AppLogger.error('DriverHomeBloc: lifecycle offline failed: $e');
    } finally {
      _isHandlingLifecycle = false;
      if (_resumeRequestedDuringLifecycle) {
        _resumeRequestedDuringLifecycle = false;
        add(DriverAppResumed());
      }
    }
  }

  Future<void> _onDriverAppResumed(
    DriverAppResumed event,
    Emitter<DriverHomeState> emit,
  ) async {
    if (_isHandlingLifecycle) {
      _resumeRequestedDuringLifecycle = true;
      return;
    }
    if (!_wasOnlineBeforeLifecyclePause) {
      if (state.isAvailable) add(RefreshDriverLocation());
      return;
    }

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    _isHandlingLifecycle = true;
    _wasOnlineBeforeLifecyclePause = false;

    try {
      final hasPermission = await _locationService.hasPermission();
      if (!hasPermission) {
        await _locationService.requestPermission();
      }

      final position = await _locationService.getCurrentLocation();
      await _repository.setDriverOnline(
        userId,
        position.latitude,
        position.longitude,
      );
      _markLocationPushed(position.latitude, position.longitude);

      emit(state.copyWith(
        isAvailable: true,
        driverLat: position.latitude,
        driverLng: position.longitude,
        isLoading: false,
      ));

      await _startLocationTracking(userId);
      _subscribeToTripOffers(userId);
      AppLogger.info('Driver ONLINE: app resumed');
    } catch (e) {
      AppLogger.error('DriverHomeBloc: lifecycle online restore failed: $e');
      emit(state.copyWith(isAvailable: false, isLoading: false));
    } finally {
      _isHandlingLifecycle = false;
    }
  }

  /// يبدأ الاستماع لتغييرات `is_available` من الداتابيز عبر realtime.
  /// يُستدعى مرة واحدة من `_onLoadDriverStatus` ويُلغى في `_onReset` / `close()`.
  void _subscribeToAvailability(String userId) {
    // تجنّب فتح أكثر من stream (مثلاً لو الـ LoadDriverStatus اشتغل تاني).
    if (_availabilitySyncSub != null) return;
    _availabilitySyncSub = _repository.watchDriverAvailability(userId).listen(
      (isAvailable) {
        // الصف اختفى → نعامله كـ غير متاح.
        add(AvailabilitySynced(isAvailable ?? false));
      },
      onError: (e) {
        AppLogger.error(
            'DriverHomeBloc: availability sync stream error: $e');
      },
    );
    AppLogger.info('DriverHomeBloc: Availability sync started for $userId');
  }

  /// يعكس حالة `is_available` القادمة من الداتابيز على الواجهة.
  /// - لو القيمة == الحالية → تجاهل (يمنع double-emit ويخلّي التغيير اليدوي سريع).
  /// - لو الداتابيز طلّعته offline (cron الـ 15 د) → نفس cleanup الـ manual offline،
  ///   لكن بدون استدعاء `setDriverOffline` لأن الداتابيز خلاص قلّبها.
  /// - لو الداتابيز رجّعته online → نحدّث الزر بس (location tracking يبدأه السواق).
  Future<void> _onAvailabilitySynced(
    AvailabilitySynced event,
    Emitter<DriverHomeState> emit,
  ) async {
    final dbAvailable = event.isAvailable;

    if (dbAvailable == state.isAvailable) return;

    AppLogger.info(
        'DriverHomeBloc: Availability synced from DB → isAvailable=$dbAvailable (was ${state.isAvailable})');

    if (!dbAvailable) {
      // الداتابيز طلّعته offline — نوقف الـ tracking وعروض الرحلات ونصفّي آخر موقع.
      _wasOnlineBeforeLifecyclePause = false;
      _lastPushedLat = null;
      _lastPushedLng = null;

      await _locationSubscription?.cancel();
      await _tripsSubscription?.cancel();
      _locationSubscription = null;
      _tripsSubscription = null;

      emit(state.copyWith(isAvailable: false, clearOffer: true));
    } else {
      // الداتابيز رجّعته online (مثلاً إعادة تفعيل من الـ admin) — حدّث الزر بس.
      emit(state.copyWith(isAvailable: true));
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
      AppLogger.info('DriverHomeBloc: Accept already in progress — ignoring');
      return;
    }
    _isAccepting = true;

    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      AppLogger.error('DriverHomeBloc: Cannot accept — not authenticated');
      _shownOfferTripIds.clear();
      _isAccepting = false;
      emit(state.copyWith(clearOffer: true));
      return;
    }

    AppLogger.debug(
        '🚦 DriverHomeBloc: Accepting trip ${event.tripId} for driver $userId');

    try {
      final tripRepo = TripDetailsRepository();
      final result = await tripRepo.acceptTrip(event.tripId);

      AppLogger.info('DriverHomeBloc: driver_accept_trip result = $result');

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

      AppLogger.debug(
          '⚠️ DriverHomeBloc: RPC accept returned error: ${result?['error'] ?? result}');
    } catch (rpcError) {
      AppLogger.debug(
          '⚠️ DriverHomeBloc: RPC accept failed ($rpcError). Trip likely unavailable.');
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
      AppLogger.error('DriverHomeBloc: Cannot reject — not authenticated');
      _trackId(_rejectedOfferTripIds, event.tripId);
      emit(state.copyWith(clearOffer: true));
      return;
    }

    AppLogger.debug(
        '🚦 DriverHomeBloc: Rejecting trip ${event.tripId} for driver $userId');

    try {
      final tripRepo = TripDetailsRepository();
      await tripRepo.rejectTripOffer(tripId: event.tripId, driverId: userId);

      AppLogger.info('DriverHomeBloc: driver_reject_trip result = success');
    } catch (rpcError) {
      AppLogger.warning('DriverHomeBloc: RPC reject failed ($rpcError).');
    }

    _trackId(_rejectedOfferTripIds, event.tripId);
    emit(state.copyWith(clearOffer: true));
  }

  Future<void> _onSubmitTripOffer(
    SubmitTripOffer event,
    Emitter<DriverHomeState> emit,
  ) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) {
      AppLogger.error(
          'DriverHomeBloc: Cannot submit offer — not authenticated');
      _trackId(_rejectedOfferTripIds, event.tripId);
      emit(state.copyWith(clearOffer: true));
      return;
    }

    AppLogger.debug(
        '🚦 DriverHomeBloc: Submitting offer ${event.proposedPrice} for trip ${event.tripId}');

    try {
      final result =
          await SupabaseService.client.rpc('driver_submit_offer', params: {
        'p_trip_id': event.tripId,
        'p_proposed_price': event.proposedPrice,
        'p_driver_lat': state.driverLat ?? 0.0,
        'p_driver_lng': state.driverLng ?? 0.0,
      });
      AppLogger.info('DriverHomeBloc: driver_submit_offer result = $result');
    } catch (e) {
      AppLogger.warning('DriverHomeBloc: RPC submit_offer failed ($e).');
    }

    _trackId(_shownOfferTripIds, event.tripId);
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
    await _pushLocationToDb(userId, event.lat, event.lng,
        heading: event.heading);
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
      await _pushLocationToDb(userId, position.latitude, position.longitude,
          heading: position.heading);
      AppLogger.info('DriverHomeBloc: Location refreshed after resume');
    } catch (e) {
      AppLogger.warning('DriverHomeBloc: RefreshDriverLocation failed: $e');
    }
  }

  double? _lastPushedLat;
  double? _lastPushedLng;
  static const double _minLocationPushDistanceMeters = 20.0;

  /// Push location to DB only on meaningful movement.
  Future<void> _pushLocationToDb(String userId, double lat, double lng,
      {double? heading, bool force = false}) async {
    if (!force && _lastPushedLat != null && _lastPushedLng != null) {
      final movedMeters =
          _haversineMeters(_lastPushedLat!, _lastPushedLng!, lat, lng);
      if (movedMeters < _minLocationPushDistanceMeters) {
        return;
      }
    }

    await _doPushLocation(userId, lat, lng, heading: heading);
  }

  void _markLocationPushed(double lat, double lng) {
    _lastPushedLat = lat;
    _lastPushedLng = lng;
  }

  static double _haversineMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMeters = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusMeters * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _doPushLocation(String userId, double lat, double lng,
      {double? heading}) async {
    try {
      await _repository.pushLocation(userId, lat, lng, heading: heading);
      _markLocationPushed(lat, lng);
    } catch (e) {
      AppLogger.error('DriverHomeBloc: Failed to push location: $e');
      return;
    }
  }

  Future<void> _onLoadHeatmapData(
    LoadHeatmapData event,
    Emitter<DriverHomeState> emit,
  ) async {
    if (_heatmapSubscription != null) return;

    // 1. Subscribe FIRST to catch any emitted events from startRealtimeUpdates
    _heatmapSubscription = _heatmapService.heatmapUpdates.listen((cells) {
      add(HeatmapDataUpdated(cells));
    });

    // 2. If Singleton already has data (Hot Reload), push it immediately
    if (_heatmapService.currentCells.isNotEmpty) {
      add(HeatmapDataUpdated(_heatmapService.currentCells));
    }

    // 3. THEN start updates
    await _heatmapService.startRealtimeUpdates();
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
        AppLogger.error('DriverHomeBloc: Location stream error: $e');
      },
    );
    AppLogger.info('DriverHomeBloc: Location tracking started for $userId');
  }

  void _subscribeToTripOffers(String userId) {
    _tripsSubscription?.cancel();
    _tripsSubscription =
        _repository.getTripOffersStream(userId).listen((offers) async {
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

        final tripList =
            await _repository.fetchTripsByIds(pendingTripIds.toList());

        for (final tripData in tripList) {
          final tripId = tripData.id;
          if (tripId.isEmpty) continue;
          _trackId(_shownOfferTripIds, tripId);
          add(NewTripOfferReceived(tripData));
          break;
        }
      } catch (e) {
        AppLogger.error('DriverHomeBloc: Failed to fetch trip offers: $e');
      }
    }, onError: (e) {
      AppLogger.error('DriverHomeBloc: Trip stream error: $e');
    });
    AppLogger.debug('🎧 DriverHomeBloc: Subscribed to trip offers for $userId');
  }

  @override
  Future<void> close() {
    _locationSubscription?.cancel();
    _tripsSubscription?.cancel();
    _heatmapSubscription?.cancel();
    _availabilitySyncSub?.cancel();
    // HeatmapService is a Singleton; logout owns its teardown.
    // Do NOT call stopRealtimeUpdates() here — it causes a Race Condition:
    // GoRouter builds the new DriverHomeScreen (new Bloc starts the service)
    // BEFORE disposing the old Bloc, so the old close() would immediately
    // kill the service the new Bloc just started.
    return super.close();
  }
}
