import 'package:equatable/equatable.dart';
import '../../../../../core/services/cell_subscription_service.dart';

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

  /// Nearby drivers map — intentionally NOT in props.
  /// We use [driversVersion] (epoch ms) as the equality signal instead.
  /// This ensures BlocListener fires on every driver update, even if
  /// the map content appears identical (e.g., driver removed then re-added).
  final Map<String, DriverLocation> nearbyDrivers;

  /// Monotonically increasing version stamp — incremented on every
  /// driver update so Equatable sees a state change.
  final int driversVersion;

  final List<Map<String, dynamic>> coupons;

  const UserHomeLoaded({
    required this.userLat,
    required this.userLng,
    required this.currentCellId,
    required this.nearbyDrivers,
    required this.coupons,
    this.driversVersion = 0,
  });

  UserHomeLoaded copyWith({
    double? userLat,
    double? userLng,
    String? currentCellId,
    Map<String, DriverLocation>? nearbyDrivers,
    bool bumpDrivers = false, // set true when nearbyDrivers changes
    List<Map<String, dynamic>>? coupons,
  }) {
    return UserHomeLoaded(
      userLat: userLat ?? this.userLat,
      userLng: userLng ?? this.userLng,
      currentCellId: currentCellId ?? this.currentCellId,
      nearbyDrivers: nearbyDrivers ?? this.nearbyDrivers,
      driversVersion:
          bumpDrivers ? DateTime.now().microsecondsSinceEpoch : driversVersion,
      coupons: coupons ?? this.coupons,
    );
  }

  @override
  List<Object?> get props =>
      [userLat, userLng, currentCellId, driversVersion, coupons];
}

class UserHomeError extends UserHomeState {
  final String message;

  const UserHomeError(this.message);

  @override
  List<Object?> get props => [message];
}
