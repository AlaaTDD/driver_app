import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/models/trip_route_plan_model.dart';
import '../../../../core/models/trip_route_waypoint_model.dart';
import '../../data/repositories/route_repository.dart';

part 'trip_route_state.dart';

/// Cubit for managing multiple routes, stopovers, and the active route plan.
class TripRouteCubit extends Cubit<TripRouteState> {
  final RouteRepository _routeRepository;
  StreamSubscription? _routePlansSub;
  StreamSubscription? _waypointsSub;

  TripRouteCubit({RouteRepository? routeRepository})
      : _routeRepository = routeRepository ?? RouteRepository(),
        super(const TripRouteState());

  @override
  Future<void> close() {
    _routePlansSub?.cancel();
    _waypointsSub?.cancel();
    return super.close();
  }

  /// Initialize and listen to route plans for a specific trip.
  void watchTripRoutes(String tripId) {
    emit(state.copyWith(status: TripRouteStatus.loading, tripId: tripId));

    _routePlansSub?.cancel();
    _routePlansSub = _routeRepository.watchRoutePlans(tripId).listen(
      (plans) {
        final activePlan = plans.where((p) => p.isActive).firstOrNull;
        
        emit(state.copyWith(
          status: TripRouteStatus.loaded,
          routePlans: plans,
          activeRoutePlan: activePlan,
        ));

        if (activePlan != null) {
          _watchWaypoints(activePlan.id);
        } else {
          _waypointsSub?.cancel();
          emit(state.copyWith(waypoints: []));
        }
      },
      onError: (err) {
        emit(state.copyWith(
          status: TripRouteStatus.error,
          errorMessage: err.toString(),
        ));
      },
    );
  }

  void _watchWaypoints(String routePlanId) {
    _waypointsSub?.cancel();
    _waypointsSub = _routeRepository.watchWaypoints(routePlanId).listen(
      (waypoints) {
        emit(state.copyWith(waypoints: waypoints));
      },
    );
  }

  /// Add a stopover to the current active route plan.
  Future<void> addStopover({
    required double lat,
    required double lng,
    String? address,
    String? placeId,
  }) async {
    final activePlan = state.activeRoutePlan;
    if (activePlan == null) {
      // Legacy backward compatibility: If no active route plan, create one from legacy trip!
      if (state.tripId != null) {
        emit(state.copyWith(status: TripRouteStatus.loading, errorMessage: null));
        final created = await _routeRepository.createRoutePlanFromLegacy(state.tripId!);
        if (created == null) {
          emit(state.copyWith(status: TripRouteStatus.error, errorMessage: "Failed to create route plan from legacy trip"));
          return;
        }
        emit(state.copyWith(status: TripRouteStatus.loaded, errorMessage: null));
      }
      return;
    }

    final newSeqOrder = state.waypoints.length + 1;

    // ✅ Clear any prior error message before optimistic update
    final tempWaypointId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempWaypoint = TripRouteWaypointModel(
      id: tempWaypointId,
      routePlanId: activePlan.id,
      seqOrder: newSeqOrder,
      role: RouteWaypointRole.stopover,
      lat: lat,
      lng: lng,
      address: address,
      placeId: placeId,
    );
    
    final previousWaypoints = List<TripRouteWaypointModel>.from(state.waypoints);
    emit(state.copyWith(waypoints: [...previousWaypoints, tempWaypoint], errorMessage: null));

    final result = await _routeRepository.addStopover(
      routePlanId: activePlan.id,
      seqOrder: newSeqOrder,
      lat: lat,
      lng: lng,
      address: address,
      placeId: placeId,
    );
    
    if (result == null) {
      // Rollback
      emit(state.copyWith(waypoints: previousWaypoints, errorMessage: "فشل إضافة المحطة"));
    }
  }

  /// Remove a stopover.
  Future<void> removeStopover(String waypointId) async {
    // ✅ Clear any prior error, then optimistic delete
    final previousWaypoints = List<TripRouteWaypointModel>.from(state.waypoints);
    final updatedWaypoints = state.waypoints.where((w) => w.id != waypointId).toList();
    emit(state.copyWith(waypoints: updatedWaypoints, errorMessage: null));

    final success = await _routeRepository.removeStopover(waypointId);
    if (!success) {
      // Rollback
      emit(state.copyWith(waypoints: previousWaypoints, errorMessage: "فشل حذف المحطة"));
    }
  }

  /// Mark a waypoint as arrived.
  Future<void> markArrived(String waypointId) async {
    await _routeRepository.markWaypointArrived(waypointId);
  }

  /// Mark a waypoint as departed.
  Future<void> markDeparted(String waypointId) async {
    await _routeRepository.markWaypointDeparted(waypointId);
  }
}
