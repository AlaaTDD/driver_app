// lib/features/user/presentation/trips/bloc/trips_event.dart
import 'package:equatable/equatable.dart';

abstract class TripsEvent extends Equatable {
  const TripsEvent();

  @override
  List<Object?> get props => [];
}

class LoadUserTrips extends TripsEvent {
  const LoadUserTrips();
}

class LoadTripDetails extends TripsEvent {
  final String tripId;

  const LoadTripDetails(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class CancelUserTrip extends TripsEvent {
  final String tripId;

  const CancelUserTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class SubmitTripComplaint extends TripsEvent {
  final String tripId;
  final String title;
  final String description;

  const SubmitTripComplaint({
    required this.tripId,
    required this.title,
    required this.description,
  });

  @override
  List<Object?> get props => [tripId, title, description];
}
