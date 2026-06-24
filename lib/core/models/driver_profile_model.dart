import 'package:equatable/equatable.dart';

/// Full driver profile model – merges data from:
///   • `users` table
///   • `drivers_profile` table
///   • `driver_earnings_summary` view
///
/// Used by [DriverProfileBloc] / [DriverProfileScreen].
class DriverProfileModel extends Equatable {
  // ── From `users` ──────────────────────────────────────────────────────────
  final String id;
  final String? name;
  final String? phone;
  final String? avatarUrl;
  final double? rating;
  final int? totalTrips;
  final String? language;
  final bool isActive;

  // ── From `drivers_profile` ────────────────────────────────────────────────
  final String nationalId;
  final String nationalIdImageUrl;
  final String licenseNumber;
  final String licenseImageUrl;
  final String criminalRecordUrl;
  final String vehicleType;
  final String vehicleBrand;
  final String vehicleModel;
  final String vehiclePlate;
  final String vehicleColor;
  final int? vehicleYear;
  final String vehicleImageUrl;
  final bool isVerified;
  final bool isAvailable;
  final double? currentLat;
  final double? currentLng;
  final String? geohash;
  final String? geohash5;
  final double? targetOriginLat;
  final double? targetOriginLng;
  final double? targetDestLat;
  final double? targetDestLng;
  final double? targetRouteLat;
  final double? targetRouteLng;
  final String? targetRouteAddress;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // ── From `driver_earnings_summary` ────────────────────────────────────────
  final double? totalEarnings;
  final double? availableBalance;
  final int? completedTripsWallet;

  const DriverProfileModel({
    required this.id,
    this.name,
    this.phone,
    this.avatarUrl,
    this.rating,
    this.totalTrips,
    this.language,
    this.isActive = true,
    this.nationalId = '',
    this.nationalIdImageUrl = '',
    this.licenseNumber = '',
    this.licenseImageUrl = '',
    this.criminalRecordUrl = '',
    this.vehicleType = '',
    this.vehicleBrand = '',
    this.vehicleModel = '',
    this.vehiclePlate = '',
    this.vehicleColor = '',
    this.vehicleYear,
    this.vehicleImageUrl = '',
    this.isVerified = false,
    this.isAvailable = false,
    this.currentLat,
    this.currentLng,
    this.geohash,
    this.geohash5,
    this.targetOriginLat,
    this.targetOriginLng,
    this.targetDestLat,
    this.targetDestLng,
    this.targetRouteLat,
    this.targetRouteLng,
    this.targetRouteAddress,
    this.createdAt,
    this.updatedAt,
    this.totalEarnings,
    this.availableBalance,
    this.completedTripsWallet,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      rating: _asDouble(json['rating']),
      totalTrips: _asInt(json['total_trips']),
      language: json['language'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      nationalId: json['national_id'] as String? ?? '',
      nationalIdImageUrl: json['national_id_image_url'] as String? ?? '',
      licenseNumber: json['license_number'] as String? ?? '',
      licenseImageUrl: json['license_image_url'] as String? ?? '',
      criminalRecordUrl: json['criminal_record_url'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? '',
      vehicleBrand: json['vehicle_brand'] as String? ?? '',
      vehicleModel: json['vehicle_model'] as String? ?? '',
      vehiclePlate: json['vehicle_plate'] as String? ?? '',
      vehicleColor: json['vehicle_color'] as String? ?? '',
      vehicleYear: _asInt(json['vehicle_year']),
      vehicleImageUrl: json['vehicle_image_url'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? false,
      currentLat: _asDouble(json['current_lat']),
      currentLng: _asDouble(json['current_lng']),
      geohash: json['geohash'] as String?,
      geohash5: json['geohash5'] as String?,
      targetOriginLat: _asDouble(json['target_origin_lat']),
      targetOriginLng: _asDouble(json['target_origin_lng']),
      targetDestLat: _asDouble(json['target_dest_lat']),
      targetDestLng: _asDouble(json['target_dest_lng']),
      targetRouteLat: _asDouble(json['target_route_lat']),
      targetRouteLng: _asDouble(json['target_route_lng']),
      targetRouteAddress: json['target_route_address'] as String?,
      createdAt: _date(json['created_at']),
      updatedAt: _date(json['updated_at']),
      totalEarnings: _asDouble(json['total_earnings']),
      availableBalance: _asDouble(json['available_balance']),
      completedTripsWallet: _asInt(json['completed_trips_wallet']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'avatar_url': avatarUrl,
        'rating': rating,
        'total_trips': totalTrips,
        'language': language,
        'is_active': isActive,
        'national_id': nationalId,
        'national_id_image_url': nationalIdImageUrl,
        'license_number': licenseNumber,
        'license_image_url': licenseImageUrl,
        'criminal_record_url': criminalRecordUrl,
        'vehicle_type': vehicleType,
        'vehicle_brand': vehicleBrand,
        'vehicle_model': vehicleModel,
        'vehicle_plate': vehiclePlate,
        'vehicle_color': vehicleColor,
        'vehicle_year': vehicleYear,
        'vehicle_image_url': vehicleImageUrl,
        'is_verified': isVerified,
        'is_available': isAvailable,
        'current_lat': currentLat,
        'current_lng': currentLng,
        'geohash': geohash,
        'geohash5': geohash5,
        'target_origin_lat': targetOriginLat,
        'target_origin_lng': targetOriginLng,
        'target_dest_lat': targetDestLat,
        'target_dest_lng': targetDestLng,
        'target_route_lat': targetRouteLat,
        'target_route_lng': targetRouteLng,
        'target_route_address': targetRouteAddress,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
        'total_earnings': totalEarnings,
        'available_balance': availableBalance,
        'completed_trips_wallet': completedTripsWallet,
      };

  Map<String, dynamic> toVehicleUpdateJson() => {
        'vehicle_type': vehicleType,
        'vehicle_brand': vehicleBrand,
        'vehicle_model': vehicleModel,
        'vehicle_year': vehicleYear,
        'vehicle_color': vehicleColor,
        'vehicle_plate': vehiclePlate,
        'vehicle_image_url': vehicleImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

  DriverProfileModel copyWith({
    String? name,
    String? phone,
    String? avatarUrl,
    double? rating,
    int? totalTrips,
    String? language,
    bool? isActive,
    String? vehicleType,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehiclePlate,
    String? vehicleColor,
    int? vehicleYear,
    String? vehicleImageUrl,
    bool? isVerified,
    bool? isAvailable,
    double? currentLat,
    double? currentLng,
    String? geohash,
    String? geohash5,
    double? totalEarnings,
    double? availableBalance,
    int? completedTripsWallet,
  }) {
    return DriverProfileModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      language: language ?? this.language,
      isActive: isActive ?? this.isActive,
      nationalId: nationalId,
      nationalIdImageUrl: nationalIdImageUrl,
      licenseNumber: licenseNumber,
      licenseImageUrl: licenseImageUrl,
      criminalRecordUrl: criminalRecordUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleImageUrl: vehicleImageUrl ?? this.vehicleImageUrl,
      isVerified: isVerified ?? this.isVerified,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      geohash: geohash ?? this.geohash,
      geohash5: geohash5 ?? this.geohash5,
      targetOriginLat: targetOriginLat,
      targetOriginLng: targetOriginLng,
      targetDestLat: targetDestLat,
      targetDestLng: targetDestLng,
      targetRouteLat: targetRouteLat,
      targetRouteLng: targetRouteLng,
      targetRouteAddress: targetRouteAddress,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      totalEarnings: totalEarnings ?? this.totalEarnings,
      availableBalance: availableBalance ?? this.availableBalance,
      completedTripsWallet: completedTripsWallet ?? this.completedTripsWallet,
    );
  }

  static double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static DateTime? _date(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  @override
  List<Object?> get props => [
        id, name, phone, avatarUrl, rating, totalTrips, language, isActive,
        nationalId, nationalIdImageUrl, licenseNumber, licenseImageUrl,
        criminalRecordUrl, vehicleType, vehicleBrand, vehicleModel,
        vehiclePlate, vehicleColor, vehicleYear, vehicleImageUrl,
        isVerified, isAvailable, currentLat, currentLng, geohash, geohash5,
        targetOriginLat, targetOriginLng, targetDestLat, targetDestLng,
        targetRouteLat, targetRouteLng, targetRouteAddress,
        createdAt, updatedAt,
        totalEarnings, availableBalance, completedTripsWallet,
      ];
}
