import 'package:equatable/equatable.dart';

abstract class DriverTripsEvent extends Equatable {
  const DriverTripsEvent();

  @override
  List<Object?> get props => [];
}

class LoadDriverTrips extends DriverTripsEvent {
  const LoadDriverTrips();
}
