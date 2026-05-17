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
  final String? cancelReason;
  final String? cancelReasonCategory;

  const CancelTrip(this.tripId, {this.cancelReason, this.cancelReasonCategory});

  @override
  List<Object?> get props => [tripId, cancelReason, cancelReasonCategory];
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

class RecalculateRoute extends TrackingEvent {
  final String tripId;

  const RecalculateRoute(this.tripId);

  @override
  List<Object?> get props => [tripId];
}
