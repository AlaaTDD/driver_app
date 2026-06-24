import '../../../../core/utils/trip_status.dart';
import '../../domain/entities/trip_entity.dart';

class TripModel extends TripEntity {
  final Map<String, dynamic>? userData;

  const TripModel({
    required super.id,
    required super.userId,
    super.driverId,
    required super.pickupAddress,
    required super.pickupLat,
    required super.pickupLng,
    required super.destinationAddress,
    required super.destinationLat,
    required super.destinationLng,
    required super.vehicleType,
    required super.distanceKm,
    required super.price,
    required super.status,
    super.paymentMethod,
    required super.isPaid,
    required super.createdAt,
    super.acceptedAt,
    super.startedAt,
    super.completedAt,
    super.geohash,
    super.meetingLat,
    super.meetingLng,
    super.meetingAddress,
    super.finalPrice,
    super.userRatingToDriver,
    super.driverRatingToUser,
    super.cancelledAt,
    super.cancelReason,
    super.cancelledBy,
    super.updatedAt,
    super.driverEarnings,
    super.platformCommission,
    super.couponDiscount,
    super.paymentSource,
    super.serviceAreaId,
    super.estimatedDurationMin,
    super.scheduledAt,
    super.cancelReasonCategory,
    this.userData,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      driverId: json['driver_id'] as String?,
      pickupAddress: json['pickup_address'] as String,
      pickupLat: (json['pickup_lat'] as num).toDouble(),
      pickupLng: (json['pickup_lng'] as num).toDouble(),
      destinationAddress: json['destination_address'] as String,
      destinationLat: (json['destination_lat'] as num).toDouble(),
      destinationLng: (json['destination_lng'] as num).toDouble(),
      vehicleType: json['vehicle_type'] as String,
      distanceKm: (json['distance_km'] as num).toDouble(),
      price: (json['price'] as num).toDouble(),
      status: TripStatus.fromString(json['status'] as String?) ??
          TripStatus.searching,
      paymentMethod: json['payment_method'] as String?,
      isPaid: json['is_paid'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      geohash: json['geohash'] as String?,
      meetingLat: json['meeting_lat'] != null
          ? (json['meeting_lat'] as num).toDouble()
          : null,
      meetingLng: json['meeting_lng'] != null
          ? (json['meeting_lng'] as num).toDouble()
          : null,
      meetingAddress: json['meeting_address'] as String?,
      finalPrice: json['final_price'] != null
          ? (json['final_price'] as num).toDouble()
          : null,
      userRatingToDriver: json['user_rating_to_driver'] != null
          ? (json['user_rating_to_driver'] as num).toDouble()
          : null,
      driverRatingToUser: json['driver_rating_to_user'] != null
          ? (json['driver_rating_to_user'] as num).toDouble()
          : null,
      cancelledAt: json['cancelled_at'] != null
          ? DateTime.parse(json['cancelled_at'] as String)
          : null,
      cancelReason: json['cancel_reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      driverEarnings: json['driver_earnings'] != null
          ? (json['driver_earnings'] as num).toDouble()
          : null,
      platformCommission: json['platform_commission'] != null
          ? (json['platform_commission'] as num).toDouble()
          : null,
      couponDiscount: json['coupon_discount'] != null
          ? (json['coupon_discount'] as num).toDouble()
          : null,
      paymentSource: json['payment_source'] as String?,
      serviceAreaId: json['service_area_id'] as String?,
      estimatedDurationMin: json['estimated_duration_min'] != null
          ? (json['estimated_duration_min'] as num).toDouble()
          : null,
      scheduledAt: json['scheduled_at'] != null
          ? DateTime.parse(json['scheduled_at'] as String)
          : null,
      cancelReasonCategory: json['cancel_reason_category'] as String?,
      userData: json['user'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'driver_id': driverId,
      'pickup_address': pickupAddress,
      'pickup_lat': pickupLat,
      'pickup_lng': pickupLng,
      'destination_address': destinationAddress,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
      'vehicle_type': vehicleType,
      'distance_km': distanceKm,
      'price': price,
      'status': status.toDbString(),
      'payment_method': paymentMethod,
      'is_paid': isPaid,
      'created_at': createdAt.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'geohash': geohash,
      'meeting_lat': meetingLat,
      'meeting_lng': meetingLng,
      'meeting_address': meetingAddress,
      'final_price': finalPrice,
      'user_rating_to_driver': userRatingToDriver,
      'driver_rating_to_user': driverRatingToUser,
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancel_reason': cancelReason,
      'cancelled_by': cancelledBy,
      'updated_at': updatedAt?.toIso8601String(),
      'driver_earnings': driverEarnings,
      'platform_commission': platformCommission,
      'coupon_discount': couponDiscount,
      'payment_source': paymentSource,
      'service_area_id': serviceAreaId,
      'estimated_duration_min': estimatedDurationMin,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'cancel_reason_category': cancelReasonCategory,
      if (userData != null) 'user': userData,
    };
  }

  TripEntity toEntity() => this;

  TripModel copyWith({
    Map<String, dynamic>? userData,
  }) {
    return TripModel(
      id: id,
      userId: userId,
      driverId: driverId,
      pickupAddress: pickupAddress,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      destinationAddress: destinationAddress,
      destinationLat: destinationLat,
      destinationLng: destinationLng,
      vehicleType: vehicleType,
      distanceKm: distanceKm,
      price: price,
      status: status,
      paymentMethod: paymentMethod,
      isPaid: isPaid,
      createdAt: createdAt,
      acceptedAt: acceptedAt,
      startedAt: startedAt,
      completedAt: completedAt,
      geohash: geohash,
      meetingLat: meetingLat,
      meetingLng: meetingLng,
      meetingAddress: meetingAddress,
      finalPrice: finalPrice,
      userRatingToDriver: userRatingToDriver,
      driverRatingToUser: driverRatingToUser,
      cancelledAt: cancelledAt,
      cancelReason: cancelReason,
      cancelledBy: cancelledBy,
      updatedAt: updatedAt,
      driverEarnings: driverEarnings,
      platformCommission: platformCommission,
      couponDiscount: couponDiscount,
      paymentSource: paymentSource,
      serviceAreaId: serviceAreaId,
      estimatedDurationMin: estimatedDurationMin,
      scheduledAt: scheduledAt,
      cancelReasonCategory: cancelReasonCategory,
      userData: userData ?? this.userData,
    );
  }

  @override
  List<Object?> get props => [...super.props, userData];
}
