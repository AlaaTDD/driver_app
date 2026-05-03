
import 'package:equatable/equatable.dart';

abstract class LocationState extends Equatable {
  const LocationState();

  @override
  List<Object?> get props => [];
}

class LocationInitial extends LocationState {}

class LocationSelectionLoading extends LocationState {}

class LocationSelected extends LocationState {
  final double lat;
  final double lng;
  final String address;

  const LocationSelected({
    required this.lat,
    required this.lng,
    required this.address,
  });

  @override
  List<Object?> get props => [lat, lng, address];
}

class LocationSelectionError extends LocationState {
  final String message;

  const LocationSelectionError(this.message);

  @override
  List<Object?> get props => [message];
}
