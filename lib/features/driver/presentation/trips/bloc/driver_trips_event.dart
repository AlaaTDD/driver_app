// lib/features/driver/presentation/trips/bloc/driver_trips_event.dart
import 'package:equatable/equatable.dart';

abstract class DriverTripsEvent extends Equatable {
  const DriverTripsEvent();

  @override
  List<Object?> get props => [];
}

class LoadDriverTrips extends DriverTripsEvent {
  const LoadDriverTrips();
}
