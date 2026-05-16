import 'package:equatable/equatable.dart';

/// Status values for a route plan (matches DB enum `route_plan_status`).
/// [CSV | section: 01_ENUM | enum: route_plan_status | values: draft,active,inactive,archived]
enum RoutePlanStatus {
  draft,
  active,
  inactive,
  archived;

  static RoutePlanStatus fromString(String? value) {
    switch (value) {
      case 'active':
        return RoutePlanStatus.active;
      case 'inactive':
        return RoutePlanStatus.inactive;
      case 'archived':
        return RoutePlanStatus.archived;
      case 'draft':
      default:
        return RoutePlanStatus.draft;
    }
  }

  String toDbString() => name;

  /// Whether this plan is currently usable.
  bool get isUsable => this == RoutePlanStatus.active || this == RoutePlanStatus.draft;

  /// Whether this plan has been deactivated/ended.
  bool get isTerminal => this == RoutePlanStatus.inactive || this == RoutePlanStatus.archived;
}

/// Maps to `trip_route_plans` table.
class TripRoutePlanModel extends Equatable {
  final String id;
  final String tripId;
  final String? label;
  final RoutePlanStatus status;
  final double? totalDistanceKm;
  final double? totalDurationMin;
  final double? estimatedPrice;
  final String? encodedPolyline;
  final bool isSystemGenerated;
  final String? createdBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const TripRoutePlanModel({
    required this.id,
    required this.tripId,
    this.label,
    this.status = RoutePlanStatus.draft,
    this.totalDistanceKm,
    this.totalDurationMin,
    this.estimatedPrice,
    this.encodedPolyline,
    this.isSystemGenerated = false,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
  });

  factory TripRoutePlanModel.fromJson(Map<String, dynamic> json) {
    return TripRoutePlanModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      label: json['label'] as String?,
      status: RoutePlanStatus.fromString(json['status'] as String?),
      totalDistanceKm: json['total_distance_km'] != null
          ? (json['total_distance_km'] as num).toDouble()
          : null,
      totalDurationMin: json['total_duration_min'] != null
          ? (json['total_duration_min'] as num).toDouble()
          : null,
      estimatedPrice: json['estimated_price'] != null
          ? (json['estimated_price'] as num).toDouble()
          : null,
      encodedPolyline: json['encoded_polyline'] as String?,
      isSystemGenerated: json['is_system_generated'] as bool? ?? false,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'trip_id': tripId,
        'label': label,
        'status': status.toDbString(),
        'total_distance_km': totalDistanceKm,
        'total_duration_min': totalDurationMin,
        'estimated_price': estimatedPrice,
        'encoded_polyline': encodedPolyline,
        'is_system_generated': isSystemGenerated,
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  bool get isActive => status == RoutePlanStatus.active;
  bool get isDraft => status == RoutePlanStatus.draft;

  @override
  List<Object?> get props => [
        id, tripId, label, status, totalDistanceKm,
        totalDurationMin, estimatedPrice, encodedPolyline,
        isSystemGenerated, createdBy, createdAt, updatedAt,
      ];
}
