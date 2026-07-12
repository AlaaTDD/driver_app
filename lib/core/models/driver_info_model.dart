import 'package:equatable/equatable.dart';

/// Lightweight driver / passenger info as returned from DB joins in trips.
///
/// This is NOT the full [DriverProfileModel] — it is the minimal subset
/// fetched from `users` + `driver_public_profile` for display in trip
/// cards and trip-details screens.
class DriverInfoModel extends Equatable {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? phone;
  final double? rating;
  final String? vehiclePlate;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? vehicleType;
  final String? vehicleCategory;

  const DriverInfoModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.phone,
    this.rating,
    this.vehiclePlate,
    this.vehicleModel,
    this.vehicleColor,
    this.vehicleType,
    this.vehicleCategory,
  });

  factory DriverInfoModel.fromJson(Map<String, dynamic> json) {
    return DriverInfoModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      phone: json['phone'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      vehiclePlate: json['vehicle_plate'] as String?,
      vehicleModel: json['vehicle_model'] as String?,
      vehicleColor: json['vehicle_color'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      vehicleCategory: json['vehicle_category'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar_url': avatarUrl,
        'phone': phone,
        'rating': rating,
        'vehicle_plate': vehiclePlate,
        'vehicle_model': vehicleModel,
        'vehicle_color': vehicleColor,
        'vehicle_type': vehicleType,
        'vehicle_category': vehicleCategory,
      };

  @override
  List<Object?> get props => [
        id,
        name,
        avatarUrl,
        phone,
        rating,
        vehiclePlate,
        vehicleModel,
        vehicleColor,
        vehicleType,
        vehicleCategory,
      ];
}
