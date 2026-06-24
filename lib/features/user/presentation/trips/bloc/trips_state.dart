import 'package:equatable/equatable.dart';
import '../../../../../core/models/trip_details_model.dart';
import '../../../../trips/data/models/trip_model.dart';

abstract class TripsState extends Equatable {
  const TripsState();

  @override
  List<Object?> get props => [];
}

class TripsInitial extends TripsState {}

class TripsLoading extends TripsState {}

class TripsLoaded extends TripsState {
  final List<TripModel> trips;

  const TripsLoaded(this.trips);

  @override
  List<Object?> get props => [trips];
}

class TripsError extends TripsState {
  final String message;

  const TripsError(this.message);

  @override
  List<Object?> get props => [message];
}

class TripDetailsLoading extends TripsState {}

class TripDetailsLoaded extends TripsState {
  final TripDetailsModel trip;

  const TripDetailsLoaded(this.trip);

  @override
  List<Object?> get props => [trip];
}

class TripActionSuccess extends TripsState {
  final String message;

  const TripActionSuccess(this.message);

  @override
  List<Object?> get props => [message];
}
