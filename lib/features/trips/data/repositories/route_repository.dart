import 'package:flutter/foundation.dart';
import '../../../../core/models/trip_route_plan_model.dart';
import '../../../../core/models/trip_route_waypoint_model.dart';
import '../../../../services/supabase_service.dart';

/// Repository for trip route plans and waypoints (stopovers).
/// Wraps Supabase RPCs and direct queries for the route system.
class RouteRepository {
  final _client = SupabaseService.client;

  // ─── Route Plans ──────────────────────────────────────────────────────────

  /// Fetch the active route plan for a trip, or null if none exists.
  Future<TripRoutePlanModel?> getActiveRoutePlan(String tripId) async {
    try {
      final data = await _client
          .from('trip_route_plans')
          .select('*')
          .eq('trip_id', tripId)
          .eq('status', 'active')
          .maybeSingle();
      if (data == null) return null;
      return TripRoutePlanModel.fromJson(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('❌ RouteRepository.getActiveRoutePlan: $e');
      return null;
    }
  }

  /// Fetch all route plans for a trip (active, draft, completed, cancelled).
  Future<List<TripRoutePlanModel>> getAllRoutePlans(String tripId) async {
    try {
      final data = await _client
          .from('trip_route_plans')
          .select('*')
          .eq('trip_id', tripId)
          .order('created_at', ascending: true);
      return (data as List)
          .map((e) => TripRoutePlanModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ RouteRepository.getAllRoutePlans: $e');
      return [];
    }
  }

  /// Use the active route view (v_trip_active_route) for backward-compatible
  /// route data including legacy single-route trips.
  Future<Map<String, dynamic>?> getActiveRouteView(String tripId) async {
    try {
      final data = await _client
          .from('v_trip_active_route')
          .select('*')
          .eq('trip_id', tripId)
          .maybeSingle();
      return data != null ? Map<String, dynamic>.from(data) : null;
    } catch (e) {
      debugPrint('❌ RouteRepository.getActiveRouteView: $e');
      return null;
    }
  }

  /// Create a route plan from legacy trip data using the DB RPC.
  Future<String?> createRoutePlanFromLegacy(String tripId) async {
    try {
      final result = await _client.rpc(
        'fn_create_route_plan_from_legacy',
        params: {'p_trip_id': tripId},
      );
      return result as String?;
    } catch (e) {
      debugPrint('❌ RouteRepository.createRoutePlanFromLegacy: $e');
      return null;
    }
  }

  // ─── Waypoints / Stopovers ────────────────────────────────────────────────

  /// Fetch waypoints for a route plan, ordered by seq_order.
  Future<List<TripRouteWaypointModel>> getWaypoints(String routePlanId) async {
    try {
      final data = await _client
          .from('trip_route_waypoints')
          .select('*')
          .eq('route_plan_id', routePlanId)
          .order('seq_order', ascending: true);
      return (data as List)
          .map((e) =>
              TripRouteWaypointModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (e) {
      debugPrint('❌ RouteRepository.getWaypoints: $e');
      return [];
    }
  }

  /// Add a stopover to a route plan using the DB RPC.
  Future<String?> addStopover({
    required String routePlanId,
    required int seqOrder,
    required double lat,
    required double lng,
    String? address,
    String? placeId,
    double? plannedWaitMin,
  }) async {
    try {
      final result = await _client.rpc(
        'fn_add_route_stopover',
        params: {
          'p_route_plan_id': routePlanId,
          'p_after_seq': seqOrder,
          'p_lat': lat,
          'p_lng': lng,
          if (address != null) 'p_address': address,
          if (plannedWaitMin != null) 'p_wait_min': plannedWaitMin,
        },
      );
      return result as String?;
    } catch (e) {
      debugPrint('❌ RouteRepository.addStopover: $e');
      return null;
    }
  }

  /// Remove a stopover from a route plan using the DB RPC.
  Future<bool> removeStopover(String waypointId) async {
    try {
      await _client.rpc(
        'fn_remove_route_stopover',
        params: {'p_waypoint_id': waypointId},
      );
      return true;
    } catch (e) {
      debugPrint('❌ RouteRepository.removeStopover: $e');
      return false;
    }
  }

  /// Mark a waypoint as arrived (driver reached the stopover).
  Future<bool> markWaypointArrived(String waypointId) async {
    try {
      await _client.from('trip_route_waypoints').update({
        'actual_arrived_at': DateTime.now().toUtc().toIso8601String()
      }).eq('id', waypointId);
      return true;
    } catch (e) {
      debugPrint('❌ RouteRepository.markWaypointArrived: $e');
      return false;
    }
  }

  /// Mark a waypoint as departed (driver left the stopover).
  Future<bool> markWaypointDeparted(String waypointId) async {
    try {
      await _client.from('trip_route_waypoints').update({
        'actual_departed_at': DateTime.now().toUtc().toIso8601String()
      }).eq('id', waypointId);
      return true;
    } catch (e) {
      debugPrint('❌ RouteRepository.markWaypointDeparted: $e');
      return false;
    }
  }

  // ─── Realtime ─────────────────────────────────────────────────────────────

  /// Stream route plan changes for a trip (realtime).
  Stream<List<TripRoutePlanModel>> watchRoutePlans(String tripId) {
    return _client
        .from('trip_route_plans')
        .stream(primaryKey: ['id'])
        .eq('trip_id', tripId)
        .map((rows) => rows
            .map((e) =>
                TripRoutePlanModel.fromJson(Map<String, dynamic>.from(e)))
            .toList());
  }

  /// Stream waypoint changes for a route plan (realtime).
  Stream<List<TripRouteWaypointModel>> watchWaypoints(String routePlanId) {
    return _client
        .from('trip_route_waypoints')
        .stream(primaryKey: ['id'])
        .eq('route_plan_id', routePlanId)
        .map((rows) => rows
            .map((e) =>
                TripRouteWaypointModel.fromJson(Map<String, dynamic>.from(e)))
            .toList()
          ..sort((a, b) => a.seqOrder.compareTo(b.seqOrder)));
  }
}
