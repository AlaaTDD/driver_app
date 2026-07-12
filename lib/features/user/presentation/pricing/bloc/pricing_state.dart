import 'package:equatable/equatable.dart';

class VehicleTypeModel extends Equatable {
  final String id; // service_tier UUID
  final String name;
  final String displayName;
  final String icon;
  final double baseFare;
  final double pricePerKm;
  final double minimumFare;
  final bool isActive;
  final int sortOrder;

  const VehicleTypeModel({
    required this.id,
    required this.name,
    required this.displayName,
    required this.icon,
    required this.baseFare,
    required this.pricePerKm,
    this.minimumFare = 0,
    this.isActive = true,
    this.sortOrder = 0,
  });

  factory VehicleTypeModel.fromJson(Map<String, dynamic> json) {
    return VehicleTypeModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String,
      displayName: json['display_name'] as String,
      icon: json['icon'] as String? ?? 'directions_car',
      baseFare: (json['base_fare'] as num).toDouble(),
      pricePerKm: (json['price_per_km'] as num).toDouble(),
      minimumFare: (json['minimum_fare'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props =>
      [id, name, displayName, icon, baseFare, pricePerKm, minimumFare, isActive, sortOrder];
}

abstract class PricingState extends Equatable {
  const PricingState();

  @override
  List<Object?> get props => [];
}

class PricingInitial extends PricingState {}

class PricingLoading extends PricingState {}

class VehicleTypesLoaded extends PricingState {
  final List<VehicleTypeModel> vehicleTypes;

  const VehicleTypesLoaded({required this.vehicleTypes});

  @override
  List<Object?> get props => [vehicleTypes];
}

class PricingCalculated extends PricingState {
  final List<VehicleTypeModel> vehicleTypes;
  final double basePrice;
  final double finalPrice;
  final String vehicleType;
  final String serviceTierId; // UUID from service_tiers
  final double distanceKm;

  const PricingCalculated({
    required this.vehicleTypes,
    required this.basePrice,
    required this.finalPrice,
    required this.vehicleType,
    required this.serviceTierId,
    required this.distanceKm,
  });

  @override
  List<Object?> get props =>
      [vehicleTypes, basePrice, finalPrice, vehicleType, serviceTierId, distanceKm];
}

class CouponApplied extends PricingState {
  final List<VehicleTypeModel> vehicleTypes;
  final String couponCode;
  final double discount;
  final double finalPrice;

  const CouponApplied({
    required this.vehicleTypes,
    required this.couponCode,
    required this.discount,
    required this.finalPrice,
  });

  @override
  List<Object?> get props => [vehicleTypes, couponCode, discount, finalPrice];
}

class CouponApplyError extends PricingCalculated {
  final String errorMessage;

  const CouponApplyError({
    required this.errorMessage,
    required super.vehicleTypes,
    required super.basePrice,
    required super.finalPrice,
    required super.vehicleType,
    required super.serviceTierId,
    required super.distanceKm,
  });

  @override
  List<Object?> get props => [...super.props, errorMessage];
}

class PricingError extends PricingState {
  final String message;
  final List<VehicleTypeModel> vehicleTypes;

  const PricingError(this.message, {this.vehicleTypes = const []});

  @override
  List<Object?> get props => [message, vehicleTypes];
}
