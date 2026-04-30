// lib/features/trips/presentation/bloc/trip_state.dart
import 'package:equatable/equatable.dart';
import '../../domain/entities/trip_entity.dart';

abstract class TripState extends Equatable {
  const TripState();

  @override
  List<Object?> get props => [];
}

class TripInitial extends TripState {}

class TripLoading extends TripState {}

class TripLoaded extends TripState {
  final List<TripEntity> trips;

  const TripLoaded(this.trips);

  @override
  List<Object?> get props => [trips];
}

class ActiveTripLoaded extends TripState {
  final TripEntity? trip;

  const ActiveTripLoaded(this.trip);

  @override
  List<Object?> get props => [trip];
}

class AvailableTripsLoaded extends TripState {
  final List<TripEntity> trips;

  const AvailableTripsLoaded(this.trips);

  @override
  List<Object?> get props => [trips];
}

class TripError extends TripState {
  final String message;

  const TripError(this.message);

  @override
  List<Object?> get props => [message];
}
