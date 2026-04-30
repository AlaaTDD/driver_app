// lib/features/user/presentation/location_selection/bloc/location_event.dart
import 'package:equatable/equatable.dart';

abstract class LocationEvent extends Equatable {
  const LocationEvent();

  @override
  List<Object?> get props => [];
}

class SelectOrigin extends LocationEvent {
  final double lat;
  final double lng;
  final String address;

  const SelectOrigin(this.lat, this.lng, this.address);

  @override
  List<Object?> get props => [lat, lng, address];
}

class SelectDestination extends LocationEvent {
  final double lat;
  final double lng;
  final String address;

  const SelectDestination(this.lat, this.lng, this.address);

  @override
  List<Object?> get props => [lat, lng, address];
}

class SelectCurrentLocation extends LocationEvent {
  const SelectCurrentLocation();
}

class SearchLocation extends LocationEvent {
  final String query;

  const SearchLocation(this.query);

  @override
  List<Object?> get props => [query];
}
