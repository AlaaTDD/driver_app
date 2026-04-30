// lib/features/driver/presentation/trip_details/bloc/trip_details_event.dart
import 'package:equatable/equatable.dart';

abstract class TripDetailsEvent extends Equatable {
  const TripDetailsEvent();

  @override
  List<Object?> get props => [];
}

class LoadTripDetails extends TripDetailsEvent {
  final String tripId;

  const LoadTripDetails(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class AcceptTrip extends TripDetailsEvent {
  final String tripId;

  const AcceptTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class RejectTrip extends TripDetailsEvent {
  final String tripId;

  const RejectTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class StartTrip extends TripDetailsEvent {
  final String tripId;

  const StartTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class CompleteTrip extends TripDetailsEvent {
  final String tripId;

  const CompleteTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}
