part of 'trip_route_cubit.dart';

enum TripRouteStatus { initial, loading, loaded, error }

class TripRouteState extends Equatable {
  final TripRouteStatus status;
  final String? tripId;
  final List<TripRoutePlanModel> routePlans;
  final TripRoutePlanModel? activeRoutePlan;
  final List<TripRouteWaypointModel> waypoints;
  final String? errorMessage;

  const TripRouteState({
    this.status = TripRouteStatus.initial,
    this.tripId,
    this.routePlans = const [],
    this.activeRoutePlan,
    this.waypoints = const [],
    this.errorMessage,
  });

  TripRouteState copyWith({
    TripRouteStatus? status,
    String? tripId,
    List<TripRoutePlanModel>? routePlans,
    TripRoutePlanModel? activeRoutePlan,
    List<TripRouteWaypointModel>? waypoints,
    String? errorMessage,
  }) {
    return TripRouteState(
      status: status ?? this.status,
      tripId: tripId ?? this.tripId,
      routePlans: routePlans ?? this.routePlans,
      activeRoutePlan: activeRoutePlan ?? this.activeRoutePlan,
      waypoints: waypoints ?? this.waypoints,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tripId,
        routePlans,
        activeRoutePlan,
        waypoints,
        errorMessage,
      ];
}
