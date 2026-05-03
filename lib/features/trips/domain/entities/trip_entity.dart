
import 'package:equatable/equatable.dart';
import '../../../../core/utils/trip_status.dart';

class TripEntity extends Equatable {
  final String id;
  final String userId;
  final String? driverId;
  final String pickupAddress;
  final double pickupLat;
  final double pickupLng;
  final String destinationAddress;
  final double destinationLat;
  final double destinationLng;
  final String vehicleType;
  final double distanceKm;
  final double price;
  final TripStatus status;
  final String? paymentMethod;
  final bool isPaid;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? geohash;
  final double? meetingLat;
  final double? meetingLng;
  final String? meetingAddress;
  final double? finalPrice;
  final double? userRatingToDriver;
  final double? driverRatingToUser;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? cancelledBy;

  const TripEntity({
    required this.id,
    required this.userId,
    this.driverId,
    required this.pickupAddress,
    required this.pickupLat,
    required this.pickupLng,
    required this.destinationAddress,
    required this.destinationLat,
    required this.destinationLng,
    required this.vehicleType,
    required this.distanceKm,
    required this.price,
    required this.status,
    this.paymentMethod,
    required this.isPaid,
    required this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.geohash,
    this.meetingLat,
    this.meetingLng,
    this.meetingAddress,
    this.finalPrice,
    this.userRatingToDriver,
    this.driverRatingToUser,
    this.cancelledAt,
    this.cancelReason,
    this.cancelledBy,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        driverId,
        pickupAddress,
        pickupLat,
        pickupLng,
        destinationAddress,
        destinationLat,
        destinationLng,
        vehicleType,
        distanceKm,
        price,
        status,
        paymentMethod,
        isPaid,
        createdAt,
        acceptedAt,
        startedAt,
        completedAt,
        geohash,
        meetingLat,
        meetingLng,
        meetingAddress,
        finalPrice,
        userRatingToDriver,
        driverRatingToUser,
        cancelledAt,
        cancelReason,
        cancelledBy,
      ];
}
