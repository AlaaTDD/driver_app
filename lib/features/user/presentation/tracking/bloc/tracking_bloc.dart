import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../../services/directions_service.dart';
import '../../../../../core/constants/env_constants.dart';
import '../../../../../services/user_presence_service.dart';
import '../../../../../services/location_service.dart';
import 'tracking_event.dart';
import 'tracking_state.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  StreamSubscription? _tripSubscription;
  StreamSubscription? _driverLocationSubscription;
  RealtimeChannel? _driverLocationChannel;

  TrackingBloc() : super(TrackingInitial()) {
    on<LoadTripTracking>(_onLoadTripTracking);
    on<CancelTrip>(_onCancelTrip);
    on<DriverLocationUpdated>(_onDriverLocationUpdated);
    on<TripCompleted>(_onTripCompleted);
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
          debugPrint('TrackingBloc: driver profile merge failed — $e');
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
            debugPrint(
                '📡 TrackingBloc: Got initial driver position $initialDriverLocation');
          }
        } catch (e) {
          debugPrint(
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
      debugPrint('❌ TrackingBloc: LoadTripTracking failed: $e');
      debugPrint(stackTrace.toString());
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

  void _onTripCompleted(
    TripCompleted event,
    Emitter<TrackingState> emit,
  ) {
    if (state is TrackingLoaded) {
      final current = state as TrackingLoaded;
      final updatedTrip = Map<String, dynamic>.from(current.trip)
        ..['status'] = 'completed';
      emit(TrackingLoaded(
        trip: updatedTrip,
        driver: current.driver,
        driverLocation: current.driverLocation,
        routePoints: current.routePoints,
      ));

      // Start broadcasting again once trip is over
      LocationService.instance.getCurrentLocation().then((loc) {
        UserPresenceService.instance
            .startBroadcasting(lat: loc.latitude, lng: loc.longitude);
      });
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
      debugPrint('⚠️ TrackingBloc: Directions fetch failed: $e');
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
      debugPrint('⚠️ TrackingBloc: stopovers fetch failed: $e');
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
    try {
      await SupabaseService.client.rpc(
        'cancel_trip',
        params: {
          'p_trip_id': event.tripId,
          'p_user_id': SupabaseService.currentUser!.id,
          'p_cancelled_by': 'user',
          if (event.cancelReason != null) 'p_cancel_reason': event.cancelReason,
        },
      );
      // Update structured category if provided
      if (event.cancelReasonCategory != null) {
        await SupabaseService.client
            .from('trips')
            .update({'cancel_reason_category': event.cancelReasonCategory}).eq(
                'id', event.tripId);
      }
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
            routePoints: current.routePoints));
      }

      // Resume broadcasting if they cancel
      final loc = await LocationService.instance.getCurrentLocation();
      await UserPresenceService.instance
          .startBroadcasting(lat: loc.latitude, lng: loc.longitude);
    } catch (e) {
      debugPrint('TrackingBloc: trip cancellation failed — $e');
    }
  }

  void _subscribeToTripUpdates(String tripId) {
    _tripSubscription?.cancel();
    _tripSubscription = SupabaseService.client
        .from('trips')
        .stream(primaryKey: ['id'])
        .eq('id', tripId)
        .listen((rows) {
          if (rows.isNotEmpty) {
            final row = rows.first;
            if (row['status'] == 'completed') {
              add(const TripCompleted());
            }
            if (row['driver_id'] != null && state is TrackingLoaded) {
              final current = state as TrackingLoaded;
              if (current.driver == null) {
                _subscribeToDriverLocation(row['driver_id'] as String);
              }
              if (row['status'] == 'in_progress' &&
                  current.trip['status'] == 'accepted') {
                // Update local state trip status first to avoid multiple recalculations
                current.trip['status'] = 'in_progress';
                add(RecalculateRoute(tripId));
              }
            }
          }
        });
  }

  void _subscribeToDriverLocation(String driverId) {
    // Cancel existing subscriptions
    _driverLocationSubscription?.cancel();
    _driverLocationChannel?.unsubscribe();

    debugPrint(
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
        debugPrint('📡 TrackingBloc: Broadcast received lat=$lat lng=$lng');
        if (lat != null && lng != null) {
          add(DriverLocationUpdated(
            lat: (lat as num).toDouble(),
            lng: (lng as num).toDouble(),
          ));
        }
      },
    )
        .subscribe((status, [error]) {
      debugPrint('📡 TrackingBloc: Channel status=$status error=$error');
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
