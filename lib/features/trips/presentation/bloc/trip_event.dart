
import 'package:equatable/equatable.dart';
import '../../../../core/utils/trip_status.dart';

abstract class TripEvent extends Equatable {
  const TripEvent();

  @override
  List<Object?> get props => [];
}

class GetUserTripsRequested extends TripEvent {
  final String userId;

  const GetUserTripsRequested(this.userId);

  @override
  List<Object?> get props => [userId];
}

class GetActiveTripRequested extends TripEvent {
  final String userId;

  const GetActiveTripRequested(this.userId);

  @override
  List<Object?> get props => [userId];
}

class CancelTripRequested extends TripEvent {
  final String tripId;

  const CancelTripRequested(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class UpdateTripStatusRequested extends TripEvent {
  final String tripId;
  final TripStatus status;

  const UpdateTripStatusRequested({
    required this.tripId,
    required this.status,
  });

  @override
  List<Object?> get props => [tripId, status];
}

class GetAvailableTripsRequested extends TripEvent {
  final double lat;
  final double lng;
  final String vehicleType;

  const GetAvailableTripsRequested({
    required this.lat,
    required this.lng,
    required this.vehicleType,
  });

  @override
  List<Object?> get props => [lat, lng, vehicleType];
}
