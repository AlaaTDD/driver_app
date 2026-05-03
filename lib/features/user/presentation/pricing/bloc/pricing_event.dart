
import 'package:equatable/equatable.dart';

abstract class PricingEvent extends Equatable {
  const PricingEvent();

  @override
  List<Object?> get props => [];
}


class LoadVehicleTypes extends PricingEvent {
  const LoadVehicleTypes();
}

class CalculatePrice extends PricingEvent {
  final String vehicleType;
  final double distanceKm;

  const CalculatePrice(this.vehicleType, this.distanceKm);

  @override
  List<Object?> get props => [vehicleType, distanceKm];
}

class ApplyCoupon extends PricingEvent {
  final String couponCode;
  final double originalPrice;

  const ApplyCoupon(this.couponCode, this.originalPrice);

  @override
  List<Object?> get props => [couponCode, originalPrice];
}
