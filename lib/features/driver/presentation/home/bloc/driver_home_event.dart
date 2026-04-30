// lib/features/driver/presentation/home/bloc/driver_home_event.dart
import 'package:equatable/equatable.dart';
import '../../../../../services/heatmap_service.dart';
import '../../../../../features/trips/data/models/trip_model.dart';

abstract class DriverHomeEvent extends Equatable {
  const DriverHomeEvent();

  @override
  List<Object?> get props => [];
}

class ToggleAvailability extends DriverHomeEvent {
  final bool isAvailable;

  const ToggleAvailability(this.isAvailable);

  @override
  List<Object?> get props => [isAvailable];
}

class LoadDriverStatus extends DriverHomeEvent {}

class NewTripOfferReceived extends DriverHomeEvent {
  final TripModel trip;
  const NewTripOfferReceived(this.trip);

  @override
  List<Object?> get props => [trip];
}

class AcceptTripOffer extends DriverHomeEvent {
  final String tripId;
  const AcceptTripOffer(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class RejectTripOffer extends DriverHomeEvent {
  final String tripId;
  const RejectTripOffer(this.tripId);

  @override
  List<Object?> get props => [tripId];
}

class DriverLocationChanged extends DriverHomeEvent {
  final double lat;
  final double lng;
  final double? heading;
  const DriverLocationChanged({required this.lat, required this.lng, this.heading});

  @override
  List<Object?> get props => [lat, lng, heading];
}

/// Load heatmap data (user density per cell)
class LoadHeatmapData extends DriverHomeEvent {}

/// Heatmap data has been updated from the service
class HeatmapDataUpdated extends DriverHomeEvent {
  final List<HeatmapCell> cells;
  const HeatmapDataUpdated(this.cells);

  @override
  List<Object?> get props => [cells];
}

/// Re-fetch the current device location and push to DB.
/// Called when the app resumes from background.
class RefreshDriverLocation extends DriverHomeEvent {}
