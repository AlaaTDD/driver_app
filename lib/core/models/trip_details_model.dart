import 'package:equatable/equatable.dart';
import 'driver_info_model.dart';

class TripDetailsModel extends Equatable {
  final String id;
  final String? userId;
  final String? driverId;
  final String status;
  final String? pickupAddress;
  final String? destinationAddress;
  final double? pickupLat;
  final double? pickupLng;
  final double? destinationLat;
  final double? destinationLng;
  final double? meetingLat;
  final double? meetingLng;
  final String? meetingAddress;
  final double? price;
  final double? finalPrice;
  final double? couponDiscount;
  final bool isPaid;
  final String? paymentMethod;
  final String? paymentSource;
  final String? vehicleType;
  final double? distanceKm;
  final double? durationMin;
  final double? driverEarnings;
  final double? platformCommission;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancelReason;
  final String? cancelReasonCategory;
  final String? cancelledBy;
  final double? userRatingToDriver;
  final double? driverRatingToUser;
  // Joined info from users / driver_public_profile tables.
  final DriverInfoModel? userData;   // passenger info (used by driver view)
  final DriverInfoModel? driverData; // driver info (used by user view)

  const TripDetailsModel({
    required this.id,
    this.userId,
    this.driverId,
    this.status = '',
    this.pickupAddress,
    this.destinationAddress,
    this.pickupLat,
    this.pickupLng,
    this.destinationLat,
    this.destinationLng,
    this.meetingLat,
    this.meetingLng,
    this.meetingAddress,
    this.price,
    this.finalPrice,
    this.couponDiscount,
    this.isPaid = false,
    this.paymentMethod,
    this.paymentSource,
    this.vehicleType,
    this.distanceKm,
    this.durationMin,
    this.driverEarnings,
    this.platformCommission,
    this.createdAt,
    this.acceptedAt,
    this.startedAt,
    this.completedAt,
    this.cancelledAt,
    this.cancelReason,
    this.cancelReasonCategory,
    this.cancelledBy,
    this.userRatingToDriver,
    this.driverRatingToUser,
    this.userData,
    this.driverData,
  });


  factory TripDetailsModel.fromJson(Map<String, dynamic> json) {
    return TripDetailsModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String?,
      driverId: json['driver_id'] as String?,
      status: json['status'] as String? ?? '',
      pickupAddress: json['pickup_address'] as String?,
      destinationAddress: json['destination_address'] as String?,
      pickupLat: _asDouble(json['pickup_lat']),
      pickupLng: _asDouble(json['pickup_lng']),
      destinationLat: _asDouble(json['destination_lat']),
      destinationLng: _asDouble(json['destination_lng']),
      meetingLat: _asDouble(json['meeting_lat']),
      meetingLng: _asDouble(json['meeting_lng']),
      meetingAddress: json['meeting_address'] as String?,
      price: _asDouble(json['price']),
      finalPrice: _asDouble(json['final_price']),
      couponDiscount: _asDouble(json['coupon_discount']),
      isPaid: json['is_paid'] as bool? ?? false,
      paymentMethod: json['payment_method'] as String?,
      paymentSource: json['payment_source'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      distanceKm: _asDouble(json['distance_km']),
      durationMin: _asDouble(json['duration_min']),
      driverEarnings: _asDouble(json['driver_earnings']),
      platformCommission: _asDouble(json['platform_commission']),
      createdAt: _date(json['created_at']),
      acceptedAt: _date(json['accepted_at']),
      startedAt: _date(json['started_at']),
      completedAt: _date(json['completed_at']),
      cancelledAt: _date(json['cancelled_at']),
      cancelReason: json['cancel_reason'] as String?,
      cancelReasonCategory: json['cancel_reason_category'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      userRatingToDriver: _asDouble(json['user_rating_to_driver']),
      driverRatingToUser: _asDouble(json['driver_rating_to_user']),
      userData: json['user'] != null
          ? DriverInfoModel.fromJson(Map<String, dynamic>.from(json['user'] as Map))
          : null,
      driverData: json['driver'] != null
          ? DriverInfoModel.fromJson(Map<String, dynamic>.from(json['driver'] as Map))
          : null,
    );
  }

  TripDetailsModel copyWith({
    String? id,
    String? userId,
    String? driverId,
    String? status,
    String? pickupAddress,
    String? destinationAddress,
    double? pickupLat,
    double? pickupLng,
    double? destinationLat,
    double? destinationLng,
    double? meetingLat,
    double? meetingLng,
    String? meetingAddress,
    double? price,
    double? finalPrice,
    double? couponDiscount,
    bool? isPaid,
    String? paymentMethod,
    String? paymentSource,
    String? vehicleType,
    double? distanceKm,
    double? durationMin,
    double? driverEarnings,
    double? platformCommission,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? cancelledAt,
    String? cancelReason,
    String? cancelReasonCategory,
    String? cancelledBy,
    double? userRatingToDriver,
    double? driverRatingToUser,
    DriverInfoModel? userData,
    DriverInfoModel? driverData,
  }) {
    return TripDetailsModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      driverId: driverId ?? this.driverId,
      status: status ?? this.status,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      destinationLat: destinationLat ?? this.destinationLat,
      destinationLng: destinationLng ?? this.destinationLng,
      meetingLat: meetingLat ?? this.meetingLat,
      meetingLng: meetingLng ?? this.meetingLng,
      meetingAddress: meetingAddress ?? this.meetingAddress,
      price: price ?? this.price,
      finalPrice: finalPrice ?? this.finalPrice,
      couponDiscount: couponDiscount ?? this.couponDiscount,
      isPaid: isPaid ?? this.isPaid,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentSource: paymentSource ?? this.paymentSource,
      vehicleType: vehicleType ?? this.vehicleType,
      distanceKm: distanceKm ?? this.distanceKm,
      durationMin: durationMin ?? this.durationMin,
      driverEarnings: driverEarnings ?? this.driverEarnings,
      platformCommission: platformCommission ?? this.platformCommission,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelReason: cancelReason ?? this.cancelReason,
      cancelReasonCategory: cancelReasonCategory ?? this.cancelReasonCategory,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      userRatingToDriver: userRatingToDriver ?? this.userRatingToDriver,
      driverRatingToUser: driverRatingToUser ?? this.driverRatingToUser,
      userData: userData ?? this.userData,
      driverData: driverData ?? this.driverData,
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        id, userId, driverId, status,
        pickupAddress, destinationAddress,
        pickupLat, pickupLng, destinationLat, destinationLng,
        meetingLat, meetingLng, meetingAddress,
        price, finalPrice, couponDiscount, isPaid,
        paymentMethod, paymentSource, vehicleType, distanceKm, durationMin,
        driverEarnings, platformCommission,
        createdAt, acceptedAt, startedAt, completedAt, cancelledAt,
        cancelReason, cancelReasonCategory, cancelledBy,
        userRatingToDriver, driverRatingToUser,
        userData, driverData,
      ];
}
