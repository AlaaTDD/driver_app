// lib/features/user/presentation/home/bloc/user_home_event.dart
import 'package:equatable/equatable.dart';
import '../../../../../services/cell_subscription_service.dart';

abstract class UserHomeEvent extends Equatable {
  const UserHomeEvent();

  @override
  List<Object?> get props => [];
}

/// Initialize the home screen — get location + subscribe to cells
class InitUserHome extends UserHomeEvent {
  final String userId;
  const InitUserHome(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// User's location has been obtained/updated
class UserLocationObtained extends UserHomeEvent {
  final double lat;
  final double lng;
  const UserLocationObtained({required this.lat, required this.lng});

  @override
  List<Object?> get props => [lat, lng];
}

/// Realtime driver location update from the cell subscription service
class DriversRealtimeUpdate extends UserHomeEvent {
  final Map<String, DriverLocation> drivers;
  const DriversRealtimeUpdate(this.drivers);

  @override
  List<Object?> get props => [drivers];
}

/// Load user's available coupons
class LoadUserCoupons extends UserHomeEvent {
  final String userId;

  const LoadUserCoupons(this.userId);

  @override
  List<Object?> get props => [userId];
}
