import 'package:equatable/equatable.dart';
import '../../../../../core/services/cell_subscription_service.dart';

abstract class UserHomeEvent extends Equatable {
  const UserHomeEvent();

  @override
  List<Object?> get props => [];
}

class InitUserHome extends UserHomeEvent {
  final String userId;
  const InitUserHome(this.userId);

  @override
  List<Object?> get props => [userId];
}

class UserLocationObtained extends UserHomeEvent {
  final double lat;
  final double lng;
  const UserLocationObtained({required this.lat, required this.lng});

  @override
  List<Object?> get props => [lat, lng];
}

class DriversRealtimeUpdate extends UserHomeEvent {
  final Map<String, DriverLocation> drivers;
  const DriversRealtimeUpdate(this.drivers);

  @override
  List<Object?> get props => [drivers];
}

class LoadUserCoupons extends UserHomeEvent {
  final String userId;

  const LoadUserCoupons(this.userId);

  @override
  List<Object?> get props => [userId];
}
