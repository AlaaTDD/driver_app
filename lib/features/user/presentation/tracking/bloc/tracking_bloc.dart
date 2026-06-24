import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../core/services/supabase_service.dart';
import '../../../../../core/services/directions_service.dart';
import '../../../../../core/constants/env_constants.dart';
import '../../../../../core/services/user_presence_service.dart';
import '../../../../../core/services/location_service.dart';
import 'tracking_event.dart';
import 'tracking_state.dart';
import 'package:snapix/core/utils/app_logger.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  StreamSubscription? _tripSubscription;
  StreamSubscription? _driverLocationSubscription;
  RealtimeChannel? _driverLocationChannel;

  TrackingBloc() : super(TrackingInitial()) {
    on<LoadTripTracking>(_onLoadTripTracking);
    on<CancelTrip>(_onCancelTrip);
    on<DriverLocationUpdated>(_onDriverLocationUpdated);
    on<TripCompleted>(_onTripCompleted);
    on<TripTerminalStatusReceived>(_onTripTerminalStatusReceived);
    on<RecalculateRoute>(_onRecalculateRoute);
  }

  Future<void> _onLoadTripTracking(
    LoadTripTracking event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingLoading());
    try {
      final tripData = await SupabaseService.client
          .from('trips')
          .select(
              '*, driver:users!trips_driver_id_fkey(id, name, phone, rating, avatar_url)')
          .eq('id', event.tripId)
          .single();

      Map<String, dynamic>? driverProfile;
      if (tripData['driver_id'] != null) {
        try {
          driverProfile = Map<String, dynamic>.from(tripData['driver'] ?? {});
          final driverProfileData = await SupabaseService.client
              .from('driver_public_profile')
              .select(
                  'id, vehicle_brand, vehicle_model, vehicle_color, vehicle_plate, is_verified')
              .eq('id', tripData['driver_id'])
              .maybeSingle();

          if (driverProfileData != null) {
            driverProfile.addAll(driverProfileData);
          }
        } catch (e) {
          AppLogger.debug('TrackingBloc: driver profile merge failed — $e');
        }
      }

      // ─── Fetch driver's current position immediately ───────────────────────
      LatLng? initialDriverLocation;
      if (tripData['driver_id'] != null) {
        try {
          final driverPos = await SupabaseService.client
              .from('driver_public_profile')
              .select('current_lat, current_lng')
              .eq('id', tripData['driver_id'])
              .maybeSingle();
          if (driverPos != null &&
              driverPos['current_lat'] != null &&
              driverPos['current_lng'] != null) {
            initialDriverLocation = LatLng(
              (driverPos['current_lat'] as num).toDouble(),
              (driverPos['current_lng'] as num).toDouble(),
            );
            AppLogger.debug(
                '📡 TrackingBloc: Got initial driver position $initialDriverLocation');
          }
        } catch (e) {
          AppLogger.debug(
              '⚠️ TrackingBloc: Failed to get initial driver position: $e');
        }
      }

      final routePoints = await _loadTripRoutePoints(event.tripId, tripData);

      emit(TrackingLoaded(
        trip: Map<String, dynamic>.from(tripData),
        driver: driverProfile,
        driverLocation: initialDriverLocation,
        routePoints: routePoints,
      ));

      // Stop broadcasting presence so the user doesn't appear on the driver's heatmap
      await UserPresenceService.instance.stopBroadcasting();

      _subscribeToTripUpdates(event.tripId);

      if (tripData['driver_id'] != null) {
        _subscribeToDriverLocation(tripData['driver_id'] as String);
      }
    } catch (e, stackTrace) {
      AppLogger.error('TrackingBloc: LoadTripTracking failed: $e');
      AppLogger.debug(stackTrace.toString());
      emit(const TrackingError('errorLoadTripDetails'));
    }
  }

  void _onDriverLocationUpdated(
    DriverLocationUpdated event,
    Emitter<TrackingState> emit,
  ) {
    if (state is TrackingLoaded) {
      final current = state as TrackingLoaded;
      emit(TrackingLoaded(
        trip: current.trip,
        driver: current.driver,
        driverLocation: LatLng(event.lat, event.lng),
        routePoints: current.routePoints,
      ));
    }
  }

  Future<void> _onTripCompleted(
    TripCompleted event,
    Emitter<TrackingState> emit,
  ) async {
    await _emitTerminalTripStatus('completed', emit);
  }

  Future<void> _onTripTerminalStatusReceived(
    TripTerminalStatusReceived event,
    Emitter<TrackingState> emit,
  ) async {
    await _emitTerminalTripStatus(event.status, emit);
  }

  Future<void> _emitTerminalTripStatus(
    String status,
    Emitter<TrackingState> emit,
  ) async {
    if (state is! TrackingLoaded) return;

    await _tripSubscription?.cancel();
    await _driverLocationSubscription?.cancel();
    _tripSubscription = null;
    _driverLocationSubscription = null;

    if (_driverLocationChannel != null) {
      await SupabaseService.client.removeChannel(_driverLocationChannel!);
      _driverLocationChannel = null;
    }

    final current = state as TrackingLoaded;
    final updatedTrip = Map<String, dynamic>.from(current.trip)
      ..['status'] = status;
    emit(TrackingLoaded(
      trip: updatedTrip,
      driver: current.driver,
      driverLocation: current.driverLocation,
      routePoints: current.routePoints,
    ));

    try {
      final loc = await LocationService.instance.getCurrentLocation();
      await UserPresenceService.instance
          .startBroadcasting(lat: loc.latitude, lng: loc.longitude);
    } catch (e) {
      AppLogger.debug('TrackingBloc: failed to resume user presence - $e');
    }
  }

  Future<void> _onRecalculateRoute(
    RecalculateRoute event,
    Emitter<TrackingState> emit,
  ) async {
    if (state is! TrackingLoaded) return;
    final current = state as TrackingLoaded;
    final tripData = current.trip;

    final routePoints = await _loadTripRoutePoints(event.tripId, tripData);

    emit(TrackingLoaded(
      trip: current.trip,
      driver: current.driver,
      driverLocation: current.driverLocation,
      routePoints: routePoints,
    ));
  }

  Future<List<LatLng>> _loadTripRoutePoints(
    String tripId,
    Map<String, dynamic> tripData,
  ) async {
    final pickup = _tripPoint(tripData, 'pickup_lat', 'pickup_lng');
    final meeting = _tripPoint(tripData, 'meeting_lat', 'meeting_lng');
    final destination =
        _tripPoint(tripData, 'destination_lat', 'destination_lng');

    if (pickup == null || destination == null) return const [];

    final hasSeparateMeeting = meeting != null && !_samePoint(meeting, pickup);
    final start = hasSeparateMeeting ? meeting : pickup;
    final stopovers = await _loadStopovers(tripId);
    final waypoints = <LatLng>[
      if (hasSeparateMeeting) pickup,
      ...stopovers,
    ];
    final fallback = <LatLng>[start, ...waypoints, destination];

    try {
      final result = await DirectionsService.getRoute(
        originLat: start.latitude,
        originLng: start.longitude,
        destLat: destination.latitude,
        destLng: destination.longitude,
        waypoints: waypoints.isNotEmpty ? waypoints : null,
        apiKey: EnvConstants.googleMapsApiKey,
      );
      if (result != null && result.points.length >= 2) return result.points;
    } catch (e) {
      AppLogger.warning('TrackingBloc: Directions fetch failed: $e');
    }

    return fallback;
  }

  Future<List<LatLng>> _loadStopovers(String tripId) async {
    try {
      final plan = await SupabaseService.client
          .from('trip_route_plans')
          .select('id')
          .eq('trip_id', tripId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (plan == null) return const [];

      final rows = await SupabaseService.client
          .from('trip_route_waypoints')
          .select('lat, lng, seq_order')
          .eq('route_plan_id', plan['id'] as String)
          .eq('role', 'stopover')
          .order('seq_order');

      return (rows as List)
          .map((row) => LatLng(
                (row['lat'] as num).toDouble(),
                (row['lng'] as num).toDouble(),
              ))
          .toList();
    } catch (e) {
      AppLogger.warning('TrackingBloc: stopovers fetch failed: $e');
      return const [];
    }
  }

  LatLng? _tripPoint(Map<String, dynamic> trip, String latKey, String lngKey) {
    final lat = (trip[latKey] as num?)?.toDouble();
    final lng = (trip[lngKey] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    if (lat == 0.0 && lng == 0.0) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    return LatLng(lat, lng);
  }

  bool _samePoint(LatLng a, LatLng b) {
    return (a.latitude - b.latitude).abs() < 0.00005 &&
        (a.longitude - b.longitude).abs() < 0.00005;
  }

  Future<void> _onCancelTrip(
    CancelTrip event,
    Emitter<TrackingState> emit,
  ) async {
    final userId = SupabaseService.currentUser?.id;
    if (userId == null) return;

    bool cancelled = false;

    // ── Attempt 1: RPC (preferred — handles business logic) ──────────────────
    try {
      await SupabaseService.client.rpc(
        'cancel_trip',
        params: {
          'p_trip_id': event.tripId,
          'p_user_id': userId,
          'p_cancelled_by': 'user',
          if (event.cancelReason != null) 'p_cancel_reason': event.cancelReason,
          if (event.cancelReasonCategory != null)
            'p_cancel_reason_category': event.cancelReasonCategory,
        },
      );
      cancelled = true;
      AppLogger.info('TrackingBloc: trip cancelled via RPC');
    } catch (e) {
      AppLogger.debug(
          '⚠️ TrackingBloc: cancel_trip RPC failed ($e) — checking DB status');
    }

    // ── RPC failed → check real DB status (handles idempotent retry races) ──
    if (!cancelled) {
      try {
        final row = await SupabaseService.client
            .from('trips')
            .select('status')
            .eq('id', event.tripId)
            .maybeSingle();
        if (row != null && row['status'] == 'cancelled') {
          cancelled = true;
          AppLogger.debug(
              '✅ TrackingBloc: trip confirmed cancelled in DB (trigger conflict was harmless)');
        }
      } catch (e) {
        AppLogger.warning('TrackingBloc: DB status check failed — $e');
      }
    }

    // ── All attempts failed → toast + stay on screen so user can retry ────────
    if (!cancelled) {
      if (state is TrackingLoaded) {
        final current = state as TrackingLoaded;
        emit(const TrackingError('errorCancelTripFailed'));
        emit(TrackingLoaded(
          trip: current.trip,
          driver: current.driver,
          driverLocation: current.driverLocation,
          routePoints: current.routePoints,
        ));
      }
      return;
    }

    // ── Success ───────────────────────────────────────────────────────────────
    await _tripSubscription?.cancel();
    await _driverLocationSubscription?.cancel();

    if (state is TrackingLoaded) {
      final current = state as TrackingLoaded;
      final updatedTrip = Map<String, dynamic>.from(current.trip)
        ..['status'] = 'cancelled';
      emit(TrackingLoaded(
        trip: updatedTrip,
        driver: current.driver,
        driverLocation: current.driverLocation,
        routePoints: current.routePoints,
      ));
    }

    // Resume broadcasting after cancel
    try {
      final loc = await LocationService.instance.getCurrentLocation();
      await UserPresenceService.instance
          .startBroadcasting(lat: loc.latitude, lng: loc.longitude);
    } catch (e, st) {
      AppLogger.warning('TrackingBloc: failed to resume presence after cancel: $e');
      AppLogger.debug(st.toString());
    }
  }

  void _subscribeToTripUpdates(String tripId) {
    _tripSubscription?.cancel();
    _tripSubscription = SupabaseService.client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .listen((rows) {
          if (rows.isEmpty) {
            add(const TripTerminalStatusReceived('cancelled'));
            return;
          }

          final row = rows.first;
          final status = row['status'] as String?;
          if (status == 'completed') {
            add(const TripCompleted());
            return;
          }
          if (status == 'cancelled') {
            add(const TripTerminalStatusReceived('cancelled'));
            return;
          }
          if (row['driver_id'] != null && state is TrackingLoaded) {
            final current = state as TrackingLoaded;
            if (current.driver == null) {
              _subscribeToDriverLocation(row['driver_id'] as String);
            }
            if (status == 'in_progress' &&
                current.trip['status'] == 'accepted') {
              // Update local state trip status first to avoid multiple recalculations
              current.trip['status'] = 'in_progress';
              add(RecalculateRoute(tripId));
            }
          }
        });
  }

  void _subscribeToDriverLocation(String driverId) {
    // Cancel existing subscriptions
    _driverLocationSubscription?.cancel();
    _driverLocationChannel?.unsubscribe();

    AppLogger.debug(
        '📡 TrackingBloc: Subscribing to driver $driverId location (broadcast)');

    // ── PRIMARY: Broadcast channel (instant, works even when driver is offline in DB) ──
    _driverLocationChannel =
        SupabaseService.client.channel('trip-tracking-$driverId');
    _driverLocationChannel!
        .onBroadcast(
      event: 'location_update',
      callback: (payload) {
        final lat = payload['lat'];
        final lng = payload['lng'];
        AppLogger.info('TrackingBloc: Broadcast received lat=$lat lng=$lng');
        if (lat != null && lng != null) {
          add(DriverLocationUpdated(
            lat: (lat as num).toDouble(),
            lng: (lng as num).toDouble(),
          ));
        }
      },
    )
        .subscribe((status, [error]) {
      AppLogger.info('TrackingBloc: Channel status=$status error=$error');
    });
  }

  @override
  Future<void> close() {
    _tripSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    if (_driverLocationChannel != null) {
      SupabaseService.client.removeChannel(_driverLocationChannel!);
    }
    return super.close();
  }
}
