import 'package:equatable/equatable.dart';
import '../../../../trips/data/models/trip_model.dart';

abstract class DriverTripsState extends Equatable {
  const DriverTripsState();

  @override
  List<Object?> get props => [];
}

class DriverTripsInitial extends DriverTripsState {}

class DriverTripsLoading extends DriverTripsState {}

class DriverTripsLoaded extends DriverTripsState {
  final List<TripModel> trips;

  const DriverTripsLoaded(this.trips);

  @override
  List<Object?> get props => [trips];
}

class DriverTripsError extends DriverTripsState {
  final String message;

  const DriverTripsError(this.message);

  @override
  List<Object?> get props => [message];
}
