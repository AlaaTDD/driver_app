
import 'package:equatable/equatable.dart';
import '../../../../../services/cell_subscription_service.dart';

abstract class UserHomeState extends Equatable {
  const UserHomeState();

  @override
  List<Object?> get props => [];
}

class UserHomeInitial extends UserHomeState {}

class UserHomeLocating extends UserHomeState {}

class UserHomeLoaded extends UserHomeState {
  final double userLat;
  final double userLng;

  
  final String currentCellId;

  
  final Map<String, DriverLocation> nearbyDrivers;

  
  final List<Map<String, dynamic>> coupons;

  const UserHomeLoaded({
    required this.userLat,
    required this.userLng,
    required this.currentCellId,
    required this.nearbyDrivers,
    required this.coupons,
  });

  UserHomeLoaded copyWith({
    double? userLat,
    double? userLng,
    String? currentCellId,
    Map<String, DriverLocation>? nearbyDrivers,
    List<Map<String, dynamic>>? coupons,
  }) {
    return UserHomeLoaded(
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      currentCellId: currentCellId ?? this.currentCellId,
      nearbyDrivers: nearbyDrivers ?? this.nearbyDrivers,
      coupons: coupons ?? this.coupons,
    );
  }

  @override
  List<Object?> get props =>
      [userLat, userLng, currentCellId, nearbyDrivers, coupons];
}

class UserHomeError extends UserHomeState {
  final String message;

  const UserHomeError(this.message);

  @override
  List<Object?> get props => [message];
}
