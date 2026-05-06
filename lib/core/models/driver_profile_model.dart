
import 'package:equatable/equatable.dart';



class DriverProfileModel extends Equatable {
  final String id;
  final String nationalId;
  final String nationalIdImageUrl;
  final String licenseNumber;
  final String licenseImageUrl;
  final String criminalRecordUrl;
  final String vehicleType;
  final String vehicleBrand;
  final String vehicleModel;
  final int vehicleYear;
  final String vehicleColor;
  final String vehiclePlate;
  final String vehicleImageUrl;
  final bool isVerified;
  final bool isAvailable;
  final double? currentLat;
  final double? currentLng;
  final String? geohash;
  final String? geohash5;
  final DateTime? updatedAt;

  const DriverProfileModel({
    required this.id,
    required this.nationalId,
    required this.nationalIdImageUrl,
    required this.licenseNumber,
    required this.licenseImageUrl,
    required this.criminalRecordUrl,
    required this.vehicleType,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehicleYear,
    required this.vehicleColor,
    required this.vehiclePlate,
    required this.vehicleImageUrl,
    this.isVerified = false,
    this.isAvailable = false,
    this.currentLat,
    this.currentLng,
    this.geohash,
    this.geohash5,
    this.updatedAt,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      id: json['id'] as String,
      nationalId: json['national_id'] as String? ?? '',
      nationalIdImageUrl: json['national_id_image_url'] as String? ?? '',
      licenseNumber: json['license_number'] as String? ?? '',
      licenseImageUrl: json['license_image_url'] as String? ?? '',
      criminalRecordUrl: json['criminal_record_url'] as String? ?? '',
      vehicleType: json['vehicle_type'] as String? ?? '',
      vehicleBrand: json['vehicle_brand'] as String? ?? '',
      vehicleModel: json['vehicle_model'] as String? ?? '',
      vehicleYear: json['vehicle_year'] as int? ?? 2020,
      vehicleColor: json['vehicle_color'] as String? ?? '',
      vehiclePlate: json['vehicle_plate'] as String? ?? '',
      vehicleImageUrl: json['vehicle_image_url'] as String? ?? '',
      isVerified: json['is_verified'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? false,
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble(),
      geohash: json['geohash'] as String?,
      geohash5: json['geohash5'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'national_id': nationalId,
      'national_id_image_url': nationalIdImageUrl,
      'license_number': licenseNumber,
      'license_image_url': licenseImageUrl,
      'criminal_record_url': criminalRecordUrl,
      'vehicle_type': vehicleType,
      'vehicle_brand': vehicleBrand,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
      'vehicle_plate': vehiclePlate,
      'vehicle_image_url': vehicleImageUrl,
      'is_verified': isVerified,
      'is_available': isAvailable,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'geohash': geohash,
      'geohash5': geohash5,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  
  Map<String, dynamic> toVehicleUpdateJson() {
    return {
      'vehicle_type': vehicleType,
      'vehicle_brand': vehicleBrand,
      'vehicle_model': vehicleModel,
      'vehicle_year': vehicleYear,
      'vehicle_color': vehicleColor,
      'vehicle_plate': vehiclePlate,
      'vehicle_image_url': vehicleImageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  DriverProfileModel copyWith({
    String? vehicleType,
    String? vehicleBrand,
    String? vehicleModel,
    int? vehicleYear,
    String? vehicleColor,
    String? vehiclePlate,
    String? vehicleImageUrl,
    bool? isVerified,
    bool? isAvailable,
    double? currentLat,
    double? currentLng,
    String? geohash,
    String? geohash5,
  }) {
    return DriverProfileModel(
      id: id,
      nationalId: nationalId,
      nationalIdImageUrl: nationalIdImageUrl,
      licenseNumber: licenseNumber,
      licenseImageUrl: licenseImageUrl,
      criminalRecordUrl: criminalRecordUrl,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehicleYear: vehicleYear ?? this.vehicleYear,
      vehicleColor: vehicleColor ?? this.vehicleColor,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      vehicleImageUrl: vehicleImageUrl ?? this.vehicleImageUrl,
      isVerified: isVerified ?? this.isVerified,
      isAvailable: isAvailable ?? this.isAvailable,
      currentLat: currentLat ?? this.currentLat,
      currentLng: currentLng ?? this.currentLng,
      geohash: geohash ?? this.geohash,
      geohash5: geohash5 ?? this.geohash5,
      updatedAt: DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id, nationalId, nationalIdImageUrl, licenseNumber, licenseImageUrl,
        criminalRecordUrl, vehicleType, vehicleBrand, vehicleModel,
        vehicleYear, vehicleColor, vehiclePlate, vehicleImageUrl,
        isVerified, isAvailable, currentLat, currentLng, geohash, geohash5,
        updatedAt,
      ];
}
