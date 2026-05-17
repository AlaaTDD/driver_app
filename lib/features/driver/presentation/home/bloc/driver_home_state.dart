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
  final double availableBalance;
  final double earningsThisWeek;
  final double rating;
  final TripModel? pendingTripOffer;

  final String? acceptedTripId;
  final String? errorMessage;

  final List<HeatmapCell> heatmapCells;

  const DriverHomeState({
    this.isAvailable = false,
    this.isLoading = false,
    this.driverLat,
    this.driverLng,
    this.totalTrips = 0,
    this.totalEarnings = 0,
    this.availableBalance = 0,
    this.earningsThisWeek = 0,
    this.rating = 0,
    this.pendingTripOffer,
    this.acceptedTripId,
    this.errorMessage,
    this.heatmapCells = const [],
  });

  DriverHomeState copyWith({
    bool? isAvailable,
    bool? isLoading,
    double? driverLat,
    double? driverLng,
    int? totalTrips,
    double? totalEarnings,
    double? availableBalance,
    double? earningsThisWeek,
    double? rating,
    TripModel? pendingTripOffer,
    bool clearOffer = false,
    String? acceptedTripId,
    bool clearAcceptedTripId = false,
    String? errorMessage,
    bool clearError = false,
    List<HeatmapCell>? heatmapCells,
  }) {
    return DriverHomeState(
      isAvailable: isAvailable ?? this.isAvailable,
      isLoading: isLoading ?? this.isLoading,
      driverLat: driverLat ?? this.driverLat,
      driverLng: driverLng ?? this.driverLng,
      totalTrips: totalTrips ?? this.totalTrips,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      availableBalance: availableBalance ?? this.availableBalance,
      earningsThisWeek: earningsThisWeek ?? this.earningsThisWeek,
      rating: rating ?? this.rating,
      pendingTripOffer:
          clearOffer ? null : (pendingTripOffer ?? this.pendingTripOffer),
      acceptedTripId:
          clearAcceptedTripId ? null : (acceptedTripId ?? this.acceptedTripId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
        availableBalance,
        earningsThisWeek,
        rating,
        pendingTripOffer,
        acceptedTripId,
        errorMessage,
        heatmapCells,
      ];
}
