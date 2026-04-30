// lib/features/user/presentation/tracking/bloc/tracking_event.dart
import 'package:equatable/equatable.dart';

abstract class TrackingEvent extends Equatable {
  const TrackingEvent();

  @override
  List<Object?> get props => [];
}

class LoadTripTracking extends TrackingEvent {
  final String tripId;

  const LoadTripTracking(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class CancelTrip extends TrackingEvent {
  final String tripId;

  const CancelTrip(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class DriverLocationUpdated extends TrackingEvent {
  final double lat;
  final double lng;

  const DriverLocationUpdated({required this.lat, required this.lng});

  @override
  List<Object?> get props => [lat, lng];
}

class TripCompleted extends TrackingEvent {
  const TripCompleted();
}
