import 'package:equatable/equatable.dart';

/// Role of a waypoint in a route plan (matches DB enum `route_waypoint_role`).
enum RouteWaypointRole {
  origin,
  stopover,
  destination;

  static RouteWaypointRole fromString(String? value) {
    switch (value) {
      case 'origin':
        return RouteWaypointRole.origin;
      case 'destination':
        return RouteWaypointRole.destination;
      case 'stopover':
      default:
        return RouteWaypointRole.stopover;
    }
  }

  String toDbString() => name;
}

/// Maps to `trip_route_waypoints` table.
class TripRouteWaypointModel extends Equatable {
  final String id;
  final String routePlanId;
  final int seqOrder;
  final RouteWaypointRole role;
  final double lat;
  final double lng;
  final String? address;
  final String? placeId;
  final double? legDistanceKm;
  final double? legDurationMin;
  final double? plannedWaitMin;
  final DateTime? actualArrivedAt;
  final DateTime? actualDepartedAt;
  final String? notes;
  final DateTime? createdAt;

  const TripRouteWaypointModel({
    required this.id,
    required this.routePlanId,
    required this.seqOrder,
    required this.role,
    required this.lat,
    required this.lng,
    this.address,
    this.placeId,
    this.legDistanceKm,
    this.legDurationMin,
    this.plannedWaitMin,
    this.actualArrivedAt,
    this.actualDepartedAt,
    this.notes,
    this.createdAt,
  });

  factory TripRouteWaypointModel.fromJson(Map<String, dynamic> json) {
    return TripRouteWaypointModel(
      id: json['id'] as String,
      routePlanId: json['route_plan_id'] as String,
      seqOrder: json['seq_order'] as int,
      role: RouteWaypointRole.fromString(json['role'] as String?),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      address: json['address'] as String?,
      placeId: json['place_id'] as String?,
      legDistanceKm: json['leg_distance_km'] != null
          ? (json['leg_distance_km'] as num).toDouble()
          : null,
      legDurationMin: json['leg_duration_min'] != null
          ? (json['leg_duration_min'] as num).toDouble()
          : null,
      plannedWaitMin: json['planned_wait_min'] != null
          ? (json['planned_wait_min'] as num).toDouble()
          : null,
      actualArrivedAt: json['actual_arrived_at'] != null
          ? DateTime.parse(json['actual_arrived_at'] as String)
          : null,
      actualDepartedAt: json['actual_departed_at'] != null
          ? DateTime.parse(json['actual_departed_at'] as String)
          : null,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'route_plan_id': routePlanId,
        'seq_order': seqOrder,
        'role': role.toDbString(),
        'lat': lat,
        'lng': lng,
        'address': address,
        'place_id': placeId,
        'leg_distance_km': legDistanceKm,
        'leg_duration_min': legDurationMin,
        'planned_wait_min': plannedWaitMin,
        'actual_arrived_at': actualArrivedAt?.toIso8601String(),
        'actual_departed_at': actualDepartedAt?.toIso8601String(),
        'notes': notes,
        'created_at': createdAt?.toIso8601String(),
      };

  bool get isOrigin => role == RouteWaypointRole.origin;
  bool get isDestination => role == RouteWaypointRole.destination;
  bool get isStopover => role == RouteWaypointRole.stopover;
  bool get hasArrived => actualArrivedAt != null;
  bool get hasDeparted => actualDepartedAt != null;

  @override
  List<Object?> get props => [
        id, routePlanId, seqOrder, role, lat, lng, address,
        placeId, legDistanceKm, legDurationMin, plannedWaitMin,
        actualArrivedAt, actualDepartedAt, notes, createdAt,
      ];
}
