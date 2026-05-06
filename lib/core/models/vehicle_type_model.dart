
import 'package:equatable/equatable.dart';
import 'package:snapix/core/localization/generated/app_localizations.dart';

/// Maps exactly to DB table: vehicle_types
/// Columns: id, name, display_name, icon, base_fare, price_per_km,
///          is_active, sort_order, created_at
class VehicleTypeModel extends Equatable {
  final String id;
  final String name;           // internal key e.g. 'economy'
  final String displayName;    // shown to user e.g. 'اقتصادية'
  final String icon;           // material icon name e.g. 'directions_car'
  final double baseFare;
  final double pricePerKm;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;

  const VehicleTypeModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.icon,
    required this.baseFare,
    required this.pricePerKm,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
  });

  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeModel(
      id:          json['id'] as String,
      name:        json['name'] as String,
      displayName: json['display_name'] as String,
      icon:        json['icon'] as String? ?? 'directions_car',
      baseFare:    (json['base_fare'] as num?)?.toDouble() ?? 0.0,
      pricePerKm:  (json['price_per_km'] as num?)?.toDouble() ?? 0.0,
      isActive:    json['is_active'] as bool? ?? true,
      sortOrder:   json['sort_order'] as int? ?? 0,
      createdAt:   json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':           id,
    'name':         name,
    'display_name': displayName,
    'icon':         icon,
    'base_fare':    baseFare,
    'price_per_km': pricePerKm,
    'is_active':    isActive,
    'sort_order':   sortOrder,
    'created_at':   createdAt.toIso8601String(),
  };

  @override
  List<Object?> get props => [id, name, displayName, baseFare, pricePerKm, isActive, sortOrder];
}
