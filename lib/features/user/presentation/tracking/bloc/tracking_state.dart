// lib/features/user/presentation/tracking/bloc/tracking_state.dart
import 'package:equatable/equatable.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract class TrackingState extends Equatable {
  const TrackingState();

  @override
  List<Object?> get props => [];
}

class TrackingInitial extends TrackingState {}

class TrackingLoading extends TrackingState {}

class TrackingLoaded extends TrackingState {
  final Map<String, dynamic> trip;
  final Map<String, dynamic>? driver;
  /// FIX P2-03: Changed from Map<String, dynamic> to typed LatLng
  final LatLng? driverLocation;
  final List<LatLng> routePoints;

  const TrackingLoaded({
    required this.trip,
    this.driver,
    this.driverLocation,
    this.routePoints = const [],
  });

  @override
  List<Object?> get props => [trip, driver, driverLocation, routePoints];
}

class TrackingError extends TrackingState {
  final String message;

  const TrackingError(this.message);

  @override
  List<Object?> get props => [message];
}
