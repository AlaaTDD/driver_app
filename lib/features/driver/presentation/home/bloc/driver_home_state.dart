// lib/features/driver/presentation/home/bloc/driver_home_state.dart
import 'package:equatable/equatable.dart';
import '../../../../../services/heatmap_service.dart';
import '../../../../../features/trips/data/models/trip_model.dart';

class DriverHomeState extends Equatable {
  final bool isAvailable;
  final bool isLoading;
  final double? driverLat;
  final double? driverLng;
  final int totalTrips;
  final double totalEarnings;
  final double rating;
  final TripModel? pendingTripOffer;

  /// FIX P1-03: Accepted trip ID for post-accept navigation
  final String? acceptedTripId;

  /// Heatmap cells — user density visualization layer
  final List<HeatmapCell> heatmapCells;

  const DriverHomeState({
    this.isAvailable = false,
    this.isLoading = false,
    this.driverLat,
    this.driverLng,
    this.totalTrips = 0,
    this.totalEarnings = 0,
    this.rating = 0,
    this.pendingTripOffer,
    this.acceptedTripId,
    this.heatmapCells = const [],
  });

  DriverHomeState copyWith({
    bool? isAvailable,
    bool? isLoading,
    double? driverLat,
    double? driverLng,
    int? totalTrips,
    double? totalEarnings,
    double? rating,
    TripModel? pendingTripOffer,
    bool clearOffer = false,
    String? acceptedTripId,
    bool clearAcceptedTripId = false,
    List<HeatmapCell>? heatmapCells,
  }) {
    return DriverHomeState(
      isAvailable: isAvailable ?? this.isAvailable,
      isLoading: isLoading ?? this.isLoading,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      totalTrips: totalTrips ?? this.totalTrips,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      rating: rating ?? this.rating,
      pendingTripOffer:
          clearOffer ? null : (pendingTripOffer ?? this.pendingTripOffer),
      acceptedTripId: clearAcceptedTripId
          ? null
          : (acceptedTripId ?? this.acceptedTripId),
      heatmapCells: heatmapCells ?? this.heatmapCells,
    );
  }

  @override
  List<Object?> get props => [
        isAvailable,
        isLoading,
        driverLat,
        driverLng,
        totalTrips,
        totalEarnings,
        rating,
        pendingTripOffer,
        acceptedTripId,
        heatmapCells,
      ];
}
