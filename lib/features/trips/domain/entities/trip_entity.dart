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
  final String? vehicleType; // Phase 3: nullable (field removed from DB)
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
  final DateTime? updatedAt;
  final double? driverEarnings;
  final double? platformCommission;
  final double? couponDiscount;
  final String? paymentSource;
  final String? serviceAreaId;
  final double? estimatedDurationMin;
  final DateTime? scheduledAt;
  final String? cancelReasonCategory;
  // Phase 3: service_tiers-based snapshot fields (trips.service_tier_id is
  // NOT NULL in the DB; the rest are nullable snapshot columns).
  final String? serviceTierId;
  final String? serviceTierNameSnapshot;
  final double? baseFareSnapshot;
  final double? pricePerKmSnapshot;
  final double? minimumFareSnapshot;
  final String? driverVehicleCategorySnapshot;

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
    this.vehicleType,
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
    this.updatedAt,
    this.driverEarnings,
    this.platformCommission,
    this.couponDiscount,
    this.paymentSource,
    this.serviceAreaId,
    this.estimatedDurationMin,
    this.scheduledAt,
    this.cancelReasonCategory,
    this.serviceTierId,
    this.serviceTierNameSnapshot,
    this.baseFareSnapshot,
    this.pricePerKmSnapshot,
    this.minimumFareSnapshot,
    this.driverVehicleCategorySnapshot,
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
        updatedAt,
        driverEarnings,
        platformCommission,
        couponDiscount,
        paymentSource,
        serviceAreaId,
        estimatedDurationMin,
        scheduledAt,
        cancelReasonCategory,
        serviceTierId,
        serviceTierNameSnapshot,
        baseFareSnapshot,
        pricePerKmSnapshot,
        minimumFareSnapshot,
        driverVehicleCategorySnapshot,
      ];
}
