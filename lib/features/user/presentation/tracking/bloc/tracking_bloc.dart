
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../../../services/supabase_service.dart';
import '../../../../../services/directions_service.dart';
import '../../../../../core/constants/env_constants.dart';
import 'tracking_event.dart';
import 'tracking_state.dart';

class TrackingBloc extends Bloc<TrackingEvent, TrackingState> {
  StreamSubscription? _tripSubscription;
  StreamSubscription? _driverLocationSubscription;

  TrackingBloc() : super(TrackingInitial()) {
    on<LoadTripTracking>(_onLoadTripTracking);
    on<CancelTrip>(_onCancelTrip);
    on<DriverLocationUpdated>(_onDriverLocationUpdated);
    on<TripCompleted>(_onTripCompleted);
  }

  Future<void> _onLoadTripTracking(
    LoadTripTracking event,
    Emitter<TrackingState> emit,
  ) async {
    emit(TrackingLoading());
    try {
      
      final tripData = await SupabaseService.client
          .from('trips')
          .select('*, driver:users!trips_driver_id_fkey(id, name, phone, rating, avatar_url)')
          .eq('id', event.tripId)
          .single();

      Map<String, dynamic>? driverProfile;
      if (tripData['driver_id'] != null) {
        try {
          driverProfile = Map<String, dynamic>.from(tripData['driver'] ?? {});
          final profileData = await SupabaseService.client
              .from('driver_profiles')
              .select('vehicle_model, vehicle_plate, vehicle_color')
              .eq('id', tripData['driver_id'])
              .maybeSingle();
          
          if (profileData != null) {
            driverProfile.addAll(profileData);
          }
        } catch (e) {
          debugPrint('TrackingBloc: driver profile merge failed — $e');
        }
      }

      
      List<LatLng> routePoints = const [];
      final pickupLat = tripData['pickup_lat'];
      final pickupLng = tripData['pickup_lng'];
      final destLat = tripData['destination_lat'];
      final destLng = tripData['destination_lng'];
      if (pickupLat != null && pickupLng != null && destLat != null && destLng != null) {
        try {
          final result = await DirectionsService.getRoute(
            originLat: (pickupLat as num).toDouble(),
            originLng: (pickupLng as num).toDouble(),
            destLat: (destLat as num).toDouble(),
            destLng: (destLng as num).toDouble(),
            apiKey: EnvConstants.googleMapsApiKey,
          );
          if (result != null) routePoints = result.points;
        } catch (e) {
          debugPrint('⚠️ TrackingBloc: Directions fetch failed: $e');
        }
      }

      emit(TrackingLoaded(
        trip: Map<String, dynamic>.from(tripData),
        driver: driverProfile,
        driverLocation: null,
        routePoints: routePoints,
      ));

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
          driverLocation: current.driverLocation));
    }
  }

  Future<void> _onCancelTrip(
    CancelTrip event,
    Emitter<TrackingState> emit,
  ) async {
    try {
      
      await SupabaseService.client
          .from('trips')
          .update({
            'status': 'cancelled',
            'cancelled_at': DateTime.now().toIso8601String(),
            'cancelled_by': 'user',
          })
          .eq('id', event.tripId)
          .eq('user_id', SupabaseService.currentUser!.id);
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
        }
      }
    });
  }

  void _subscribeToDriverLocation(String driverId) {
    _driverLocationSubscription?.cancel();
    
    _driverLocationSubscription = SupabaseService.client
        .from('drivers_profile')
        .stream(primaryKey: ['id'])
        .eq('id', driverId)
        .listen((rows) {
      if (rows.isNotEmpty) {
        final row = rows.first;
        final lat = row['current_lat'];
        final lng = row['current_lng'];
        if (lat != null && lng != null) {
          add(DriverLocationUpdated(
            lat: (lat as num).toDouble(),
            lng: (lng as num).toDouble(),
          ));
        }
      }
    });
  }

  @override
  Future<void> close() {
    _tripSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    return super.close();
  }
}
