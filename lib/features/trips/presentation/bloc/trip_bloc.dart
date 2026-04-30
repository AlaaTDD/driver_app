// lib/features/trips/presentation/bloc/trip_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../services/supabase_service.dart';
import '../../domain/repositories/trip_repository.dart';
import 'trip_event.dart';
import 'trip_state.dart';

class TripBloc extends Bloc<TripEvent, TripState> {
  final TripRepository _tripRepository;

  TripBloc(this._tripRepository) : super(TripInitial()) {
    on<CreateTripRequested>(_onCreateTripRequested);
    on<GetUserTripsRequested>(_onGetUserTripsRequested);
    on<GetActiveTripRequested>(_onGetActiveTripRequested);
    on<CancelTripRequested>(_onCancelTripRequested);
    on<UpdateTripStatusRequested>(_onUpdateTripStatusRequested);
    on<GetAvailableTripsRequested>(_onGetAvailableTripsRequested);
  }

  Future<void> _onCreateTripRequested(
    CreateTripRequested event,
    Emitter<TripState> emit,
  ) async {
    emit(TripLoading());
    final result = await _tripRepository.createTrip(
      userId: SupabaseService.currentUser!.id,
      pickupAddress: event.pickupAddress,
      pickupLat: event.pickupLat,
      pickupLng: event.pickupLng,
      destinationAddress: event.destinationAddress,
      destinationLat: event.destinationLat,
      destinationLng: event.destinationLng,
      vehicleType: event.vehicleType,
      distanceKm: event.distanceKm,
      price: event.price,
    );
    result.fold(
      (error) => emit(TripError(error)),
      (trip) => emit(ActiveTripLoaded(trip)),
    );
  }

  Future<void> _onGetUserTripsRequested(
    GetUserTripsRequested event,
    Emitter<TripState> emit,
  ) async {
    emit(TripLoading());
    final result = await _tripRepository.getUserTrips(event.userId);
    result.fold(
      (error) => emit(TripError(error)),
      (trips) => emit(TripLoaded(trips)),
    );
  }

  Future<void> _onGetActiveTripRequested(
    GetActiveTripRequested event,
    Emitter<TripState> emit,
  ) async {
    emit(TripLoading());
    final result = await _tripRepository.getActiveTrip(event.userId);
    result.fold(
      (error) => emit(TripError(error)),
      (trip) => emit(ActiveTripLoaded(trip)),
    );
  }

  Future<void> _onCancelTripRequested(
    CancelTripRequested event,
    Emitter<TripState> emit,
  ) async {
    emit(TripLoading());
    final result = await _tripRepository.cancelTrip(
      tripId: event.tripId,
      cancelledBy: 'user',
    );
    result.fold(
      (error) => emit(TripError(error)),
      (_) => emit(TripInitial()),
    );
  }

  Future<void> _onUpdateTripStatusRequested(
    UpdateTripStatusRequested event,
    Emitter<TripState> emit,
  ) async {
    emit(TripLoading());
    final result = await _tripRepository.updateTripStatus(
      tripId: event.tripId,
      newStatus: event.status,
    );
    result.fold(
      (error) => emit(TripError(error)),
      (_) => emit(TripInitial()),
    );
  }

  Future<void> _onGetAvailableTripsRequested(
    GetAvailableTripsRequested event,
    Emitter<TripState> emit,
  ) async {
    emit(TripLoading());
    final result = await _tripRepository.getAvailableTrips(
      lat: event.lat,
      lng: event.lng,
      vehicleType: event.vehicleType,
    );
    result.fold(
      (error) => emit(TripError(error)),
      (trips) => emit(AvailableTripsLoaded(trips)),
    );
  }
}
