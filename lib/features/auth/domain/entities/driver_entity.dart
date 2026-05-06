
import 'package:equatable/equatable.dart';

class DriverEntity extends Equatable {
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
  final String? geohash5;
  final double? currentLat;
  final double? currentLng;
  final double? heading;
  final DateTime updatedAt;

  const DriverEntity({
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
    this.geohash5,
    this.currentLat,
    this.currentLng,
    this.heading,
    required this.updatedAt,
  });

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
        geohash5,
        currentLat,
        currentLng,
        heading,
        updatedAt,
      ];
}
