
import 'package:equatable/equatable.dart';
import '../../domain/entities/driver_entity.dart';

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
  final String? geohash;
  final double? currentLat;
  final double? currentLng;
  final DateTime updatedAt;

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
    required this.isVerified,
    required this.isAvailable,
    this.geohash,
    this.currentLat,
    this.currentLng,
    required this.updatedAt,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    return DriverProfileModel(
      id: json['id'] as String,
      nationalId: json['national_id'] as String,
      nationalIdImageUrl: json['national_id_image_url'] as String,
      licenseNumber: json['license_number'] as String,
      licenseImageUrl: json['license_image_url'] as String,
      criminalRecordUrl: json['criminal_record_url'] as String,
      vehicleType: json['vehicle_type'] as String,
      vehicleBrand: json['vehicle_brand'] as String,
      vehicleModel: json['vehicle_model'] as String,
      vehicleYear: json['vehicle_year'] as int,
      vehicleColor: json['vehicle_color'] as String,
      vehiclePlate: json['vehicle_plate'] as String,
      vehicleImageUrl: json['vehicle_image_url'] as String,
      isVerified: json['is_verified'] as bool? ?? false,
      isAvailable: json['is_available'] as bool? ?? false,
      geohash: json['geohash'] as String?,
      currentLat: (json['current_lat'] as num?)?.toDouble(),
      currentLng: (json['current_lng'] as num?)?.toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
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
      'geohash': geohash,
      'current_lat': currentLat,
      'current_lng': currentLng,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  DriverEntity toEntity() {
    return DriverEntity(
      id: id,
      nationalId: nationalId,
      nationalIdImageUrl: nationalIdImageUrl,
      licenseNumber: licenseNumber,
      licenseImageUrl: licenseImageUrl,
      criminalRecordUrl: criminalRecordUrl,
      vehicleType: vehicleType,
      vehicleBrand: vehicleBrand,
      vehicleModel: vehicleModel,
      vehicleYear: vehicleYear,
      vehicleColor: vehicleColor,
      vehiclePlate: vehiclePlate,
      vehicleImageUrl: vehicleImageUrl,
      isVerified: isVerified,
      isAvailable: isAvailable,
      geohash: geohash,
      currentLat: currentLat,
      currentLng: currentLng,
      updatedAt: updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        nationalId,
        nationalIdImageUrl,
        licenseNumber,
        licenseImageUrl,
        criminalRecordUrl,
        vehicleType,
        vehicleBrand,
        vehicleModel,
        vehicleYear,
        vehicleColor,
        vehiclePlate,
        vehicleImageUrl,
        isVerified,
        isAvailable,
        geohash,
        currentLat,
        currentLng,
        updatedAt,
      ];
}
